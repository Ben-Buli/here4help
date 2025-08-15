# Chat 頁面置頂功能

## 🎯 功能概述

在 `/chat` 頁面的 Posted Tasks 分頁中，新增了圖釘圖標按鈕，實現任務置頂功能。置頂的任務會優先排序顯示，並且不會被篩選或搜尋條件重置。

## 🚀 核心特性

### 1. 置頂狀態管理
- **持久化置頂**：置頂狀態不會被篩選、搜尋或 tab 切換重置
- **視覺反饋**：置頂任務使用橙色邊框和陰影突出顯示
- **圖標切換**：實心圖釘（已置頂）vs 空心圖釘（未置頂）

### 2. 優先排序邏輯
- **最高優先級**：置頂任務始終排在非置頂任務前面
- **智能排序**：在置頂任務內部，按原有排序邏輯排列
- **篩選友好**：搜尋和篩選時，置頂任務仍然優先顯示

### 3. UI 樣式更新
- **任務卡片**：置頂任務使用橙色邊框（2px）和更高陰影
- **應徵者卡片**：置頂任務的應徵者卡片也使用橙色邊框
- **圖標顏色**：置頂狀態使用橙色，未置頂使用主題色

## 🏗️ 技術實現

### 狀態管理
```dart
// 置頂任務管理
final Set<String> _pinnedTaskIds = <String>{};

// 切換置頂狀態
void _toggleTaskPin(String taskId) {
  setState(() {
    if (_pinnedTaskIds.contains(taskId)) {
      _pinnedTaskIds.remove(taskId);
    } else {
      _pinnedTaskIds.add(taskId);
    }
  });
  
  // 刷新分頁控制器以應用新的排序
  _pagingController.refresh();
}

// 檢查是否置頂
bool _isTaskPinned(String taskId) {
  return _pinnedTaskIds.contains(taskId);
}
```

### 排序邏輯
```dart
sortedTasks.sort((a, b) {
  final taskIdA = a['id']?.toString() ?? '';
  final taskIdB = b['id']?.toString() ?? '';
  
  // 置頂任務優先排序（最高優先級）
  final isPinnedA = _isTaskPinned(taskIdA);
  final isPinnedB = _isTaskPinned(taskIdB);
  
  if (isPinnedA && !isPinnedB) return -1; // A 置頂，B 不置頂，A 在前
  if (!isPinnedA && isPinnedB) return 1;  // A 不置頂，B 置頂，B 在前
  
  // 非置頂任務按原有邏輯排序
  // ... 原有排序邏輯
});
```

### UI 組件更新
```dart
// Action Bar 中的圖釘按鈕
Expanded(
  child: IconButton(
    onPressed: () => _toggleTaskPin(taskId),
    icon: Icon(
      _isTaskPinned(taskId) 
          ? Icons.push_pin           // 實心圖釘（已置頂）
          : Icons.push_pin_outlined, // 空心圖釘（未置頂）
      size: 18,
      color: _isTaskPinned(taskId) 
          ? Colors.orange           // 置頂狀態使用橙色
          : colorScheme.primary,    // 未置頂使用主題色
    ),
    tooltip: _isTaskPinned(taskId) ? '取消置頂' : '置頂任務',
  ),
),

// 任務卡片邊框樣式
shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(12),
  side: _isTaskPinned(taskId) 
      ? BorderSide(color: Colors.orange, width: 2)  // 置頂：橙色邊框
      : BorderSide.none,                            // 未置頂：無邊框
),
elevation: _isTaskPinned(taskId) ? 2 : 1,          // 置頂：更高陰影
```

## 📱 用戶體驗

### 操作流程
1. **點擊圖釘圖標**：切換任務的置頂狀態
2. **視覺反饋**：圖標從空心變為實心，顏色變為橙色
3. **邊框更新**：任務卡片和應徵者卡片邊框變為橙色
4. **排序更新**：置頂任務自動移動到列表頂部

### 狀態保持
- **篩選保持**：搜尋和篩選時，置頂狀態不變
- **Tab 切換保持**：切換到 My Works 再回來，置頂狀態保持
- **排序保持**：改變排序方式時，置頂任務仍然優先

## 🎨 視覺設計

### 顏色方案
- **置頂狀態**：`Colors.orange`（橙色）
- **未置頂狀態**：`colorScheme.primary`（主題色）
- **邊框寬度**：2px（置頂）vs 無邊框（未置頂）
- **陰影效果**：elevation 2（置頂）vs elevation 1（未置頂）

### 圖標設計
- **已置頂**：`Icons.push_pin`（實心圖釘）
- **未置頂**：`Icons.push_pin_outlined`（空心圖釘）
- **圖標大小**：18px
- **工具提示**：動態顯示「置頂任務」或「取消置頂」

## 🔧 配置選項

### 邊框樣式
```dart
// 可以調整邊框顏色和寬度
side: _isTaskPinned(taskId) 
    ? BorderSide(color: Colors.orange, width: 2)  // 可調整顏色和寬度
    : BorderSide.none,
```

### 陰影效果
```dart
// 可以調整陰影強度
elevation: _isTaskPinned(taskId) ? 2 : 1,  // 可調整數值
```

### 圖標顏色
```dart
// 可以調整置頂狀態的顏色
color: _isTaskPinned(taskId) 
    ? Colors.orange  // 可調整為其他顏色
    : colorScheme.primary,
```

## 📊 性能優化

### 狀態檢查優化
- **Set 查找**：使用 `Set<String>` 進行 O(1) 時間複雜度的置頂狀態檢查
- **避免重複計算**：在排序時一次性檢查置頂狀態
- **最小化重建**：只在置頂狀態改變時觸發 UI 重建

### 排序優化
- **優先級分離**：置頂檢查在排序邏輯的最前面，避免不必要的比較
- **早期返回**：發現置頂狀態差異時立即返回結果

## 🔮 未來擴展

### 置頂時間記錄
```dart
// 可以擴展為記錄置頂時間
final Map<String, DateTime> _pinnedTaskTimestamps = {};

// 在置頂時記錄時間
_pinnedTaskTimestamps[taskId] = DateTime.now();

// 按置頂時間排序
if (isPinnedA && isPinnedB) {
  final timeA = _pinnedTaskTimestamps[taskIdA] ?? DateTime.now();
  final timeB = _pinnedTaskTimestamps[taskIdB] ?? DateTime.now();
  return timeA.compareTo(timeB); // 先置頂的在前面
}
```

### 置頂數量限制
```dart
// 可以限制最大置頂數量
static const int maxPinnedTasks = 5;

void _toggleTaskPin(String taskId) {
  if (!_pinnedTaskIds.contains(taskId) && _pinnedTaskIds.length >= maxPinnedTasks) {
    // 顯示提示：已達到最大置頂數量
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('最多只能置頂 5 個任務')),
    );
    return;
  }
  // ... 原有邏輯
}
```

### 置頂分組顯示
```dart
// 可以將置頂任務分組顯示
if (_pinnedTaskIds.isNotEmpty) {
  // 顯示置頂任務組
  Text('置頂任務', style: TextStyle(fontWeight: FontWeight.bold)),
  ...pinnedTasks.map((task) => _buildTaskCard(task)),
  
  // 顯示分隔線
  Divider(),
  
  // 顯示普通任務組
  Text('其他任務', style: TextStyle(fontWeight: FontWeight.bold)),
  ...normalTasks.map((task) => _buildTaskCard(task)),
}
```

## 📝 使用注意事項

1. **狀態持久化**：目前置頂狀態只在記憶體中，App 重啟後會重置
2. **性能考慮**：置頂任務數量過多可能影響排序性能
3. **用戶教育**：需要通過 UI 提示讓用戶了解置頂功能
4. **一致性**：確保置頂狀態在所有相關 UI 組件中保持一致

## 🎉 總結

置頂功能通過以下方式提升了用戶體驗：

- **快速訪問**：重要任務始終在列表頂部，無需滾動查找
- **視覺突出**：橙色邊框和陰影讓置頂任務一目了然
- **狀態保持**：置頂狀態不會被其他操作意外重置
- **智能排序**：在保持優先級的同時，遵循用戶的排序偏好

為用戶提供了更靈活和高效的任務管理體驗！🎯✨
