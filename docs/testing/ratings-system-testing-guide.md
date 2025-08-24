# 🎯 評分系統前端測試指南

## 📋 測試概述

本指南幫助你驗證評分系統的前後端對接是否正確，涵蓋所有三個分頁的 UI 邏輯。

### 🔑 測試用戶
- **用戶 ID**: 2
- **測試資料**: 已為此用戶創建完整的測試場景

## 🚀 測試步驟

### 1. 準備工作
1. 確保 MAMP 運行在 `localhost:8888`
2. 確保 Flutter 應用運行
3. 登入或使用 user_id=2 的 JWT token

### 2. Posted 分頁測試 (我發佈的任務)

#### 📊 測試場景
| 任務 | 狀態 | 參與者 | 評分狀態 | 預期 UI |
|------|------|--------|----------|---------|
| `[Posted] Completed - Already Rated` | Completed | User 3 | 已評分 ⭐4 | 顯示 ⭐4 (可點擊查看) |
| `[Posted] Completed - Awaiting Rating` | Completed | User 3 | 未評分 (可評分) | 顯示 'Rate' 按鈕 |
| `[Posted] Open Task` | Open | 無 | N/A | 顯示狀態標籤 'Open' |
| `[Posted] In Progress Task` | In Progress | User 3 | N/A | 顯示狀態標籤 'In Progress' |
| `[Posted] Pending Confirmation` | Pending Confirmation | User 3 | N/A | 顯示狀態標籤 'Pending Confirmation' |

#### ✅ 測試檢查點
- [ ] 已評分任務顯示星級評分 (⭐4)
- [ ] 點擊星級評分開啟只讀對話框，顯示評分詳情
- [ ] 未評分完成任務顯示 'Rate' 按鈕
- [ ] 點擊 'Rate' 按鈕開啟評分對話框 (1-5星 + 評論)
- [ ] 進行中任務顯示對應的狀態標籤
- [ ] 評分對話框要求評論為必填

### 3. Accepted 分頁測試 (我接案的任務)

#### 📊 測試場景
| 任務 | 狀態 | 創建者 | 評分狀態 | 預期 UI |
|------|------|--------|----------|---------|
| `Test Accepted Task [ACCEPTED-TEST: ...]` | Completed | User 1 | 創建者已評分 ⭐5 | 顯示 ⭐5 (可點擊查看) |
| `Home Internet Plan Setup [ACCEPTED-TEST: ...]` | Completed | User 1 | 創建者未評分 | 顯示 'Awaiting review' |
| `Test Rejected Task [ACCEPTED-TEST: ...]` | In Progress | User 1 | N/A | 顯示狀態標籤 'In Progress' |

#### ✅ 測試檢查點
- [ ] 已被評分任務顯示星級評分 (⭐5)
- [ ] 點擊星級評分開啟只讀對話框，顯示創建者的評分
- [ ] 未被評分完成任務顯示 'Awaiting review' 標籤
- [ ] 進行中任務顯示狀態標籤
- [ ] 無法對創建者進行評分 (只能查看)

### 4. Not Selected 分頁測試 (我的應徵記錄)

#### 📊 測試場景
包含多種應徵狀態：`applied`, `rejected`, `cancelled`, `withdrawn`

#### ✅ 測試檢查點
- [ ] 顯示各種應徵狀態的任務列表
- [ ] 每個任務顯示應徵狀態標籤
- [ ] 點擊任務開啟任務詳情對話框
- [ ] 對話框顯示任務標題、日期、獎勵、狀態

## 🔧 前端調整建議

### 1. ratings_page.dart 優化

你的 `ratings_page.dart` 已經基於舊架構調整，以下是一些可能的優化：

```dart
// 在 _loadPostedTasks 中添加 debug 輸出
Future<void> _loadPostedTasks({bool refresh = false}) async {
  try {
    final result = await RatingsService.fetchPosted(1);
    print('DEBUG: Posted tasks loaded: ${result.items.length}');
    for (var task in result.items) {
      print('  - ${task.title}: status=${task.statusId}, hasRating=${task.hasRating}, canRate=${task.canRate}');
    }
    // ... rest of the method
  } catch (e) {
    print('DEBUG: Posted tasks error: $e');
    // ... error handling
  }
}
```

### 2. 確保 Token 正確傳遞

檢查 `RatingsService` 是否正確使用 user_id=2 的 JWT token：

```dart
// 在 ratings_service.dart 中添加 debug
static Future<Paged<TaskCard>> fetchPosted(int page) async {
  print('DEBUG: Fetching posted tasks for page $page');
  final response = await HttpClientService.get(
    '$_baseUrl/backend/api/ratings/posted.php?page=$page&per_page=20',
    useQueryParamToken: true, // 確保 MAMP 兼容性
  );
  print('DEBUG: Response status: ${response.statusCode}');
  // ... rest of the method
}
```

### 3. UI 狀態檢查

在 `_buildPostedActionArea` 中添加更詳細的邏輯檢查：

```dart
Widget _buildPostedActionArea(TaskCard task) {
  print('DEBUG Action Area: ${task.title}');
  print('  - isCompleted: ${task.isCompleted} (statusId: ${task.statusId})');
  print('  - hasRating: ${task.hasRating}');
  print('  - canRate: ${task.canRate}');
  
  if (task.isUnfinished) {
    print('  -> Showing status pill: ${task.statusName}');
    return _buildStatusPill(task.statusName);
  } else if (task.isCompleted) {
    if (task.hasRating) {
      print('  -> Showing rating: ${task.rating!.rating}');
      return Row(/* ... rating display ... */);
    } else if (task.canRate) {
      print('  -> Showing Rate button');
      return ElevatedButton(/* ... rate button ... */);
    } else {
      print('  -> Showing Awaiting review');
      return Container(/* ... awaiting review ... */);
    }
  }
  
  print('  -> Fallback to status pill');
  return _buildStatusPill(task.statusName);
}
```

## 🐛 常見問題排查

### 1. API 無資料
- 檢查 JWT token 是否對應 user_id=2
- 檢查 MAMP 是否運行在正確端口
- 檢查後端 API 是否正確回傳資料

### 2. UI 顯示不正確
- 檢查 `TaskCard.fromJson()` 是否正確解析後端資料
- 檢查 `isCompleted`, `hasRating`, `canRate` 的邏輯判斷
- 檢查 Action Area 的條件分支

### 3. 評分功能異常
- 檢查評分對話框的驗證邏輯
- 檢查 `RatingsService.createRating()` 的參數傳遞
- 檢查評分提交後的頁面刷新

## 📊 測試資料統計

- **📋 Posted**: 5 個任務 (涵蓋所有狀態)
- **✅ Accepted**: 7 個任務 (包含評分場景)
- **❌ Not Selected**: 15+ 個應徵記錄 (多種狀態)

## 🎉 測試完成標準

當所有檢查點都通過時，表示評分系統的前後端對接完全正確，可以進入生產環境。

---

**💡 提示**: 如果遇到問題，可以查看瀏覽器開發者工具的 Console 和 Network 標籤來診斷 API 調用和前端邏輯。
