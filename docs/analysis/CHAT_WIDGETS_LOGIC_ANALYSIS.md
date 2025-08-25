# Posted Tasks & My Works Widget 邏輯分析報告

## 📋 **概述**

本報告詳細分析 `posted_tasks_widget.dart` 和 `my_works_widget.dart` 兩個聊天分頁組件的資料取得、查詢、排序、篩選、重設邏輯。

## 🔍 **Posted Tasks Widget 分析**

### **📊 資料取得邏輯**

#### **1. 資料來源架構**
```dart
// 多層資料管理
final List<Map<String, dynamic>> _allTasks = [];           // 原始任務資料
List<Map<String, dynamic>> _filteredTasks = [];           // 篩選後資料
List<Map<String, dynamic>> _sortedTasks = [];             // 排序後資料
final Map<String, List<Map<String, dynamic>>> _applicationsByTask = {}; // 應徵者資料
```

#### **2. 資料載入流程**
```dart
void _checkAndLoadIfNeeded() {
  // 1. 檢查 Provider 初始化狀態
  if (!chatProvider.isInitialized) return;
  
  // 2. 檢查是否為當前分頁
  if (chatProvider.isPostedTasksTab) {
    // 3. 檢查載入狀態
    if (!chatProvider.isTabLoaded(TAB_POSTED_TASKS) && 
        !chatProvider.isTabLoading(TAB_POSTED_TASKS)) {
      // 4. 觸發載入
      chatProvider.checkAndTriggerTabLoad(TAB_POSTED_TASKS);
      _fetchAllTasks(); // 直接調用 API
    }
  }
}
```

#### **3. API 調用策略**
```dart
Future<void> _fetchAllTasks() async {
  // 使用聚合 API 一次性獲取任務和應徵者資料
  final result = await TaskService().fetchPostedTasksAggregated(
    creatorId: currentUserId.toString(),
    limit: 50,
    offset: 0,
  );
  
  // 更新本地資料
  _allTasks.clear();
  _allTasks.addAll(result.tasks);
  
  // 載入應徵者資料
  await _loadApplicantsData();
  
  // 應用篩選和排序
  _applyFiltersAndSort();
}
```

### **🔍 查詢邏輯**

#### **多欄位搜尋 + 相關性評分**
```dart
List<Map<String, dynamic>> _filterTasks(tasks, chatProvider) {
  return tasks.where((task) {
    final rawQuery = chatProvider.searchQuery.trim();
    final normalizedQuery = _normalizeSearchText(rawQuery.toLowerCase());
    
    // 相關性評分系統
    int relevanceScore = 0;
    if (nTitle.contains(normalizedQuery)) relevanceScore += 3;    // 標題權重最高
    if (nTags.contains(normalizedQuery)) relevanceScore += 2;     // 標籤次之
    if (nDesc.contains(normalizedQuery)) relevanceScore += 1;     // 描述
    if (nLoc.contains(normalizedQuery)) relevanceScore += 1;      // 位置
    if (nLang.contains(normalizedQuery)) relevanceScore += 1;     // 語言
    if (nStatus.contains(normalizedQuery)) relevanceScore += 1;   // 狀態
    
    // 將相關性分數掛到任務上供排序使用
    task['_relevance'] = relevanceScore;
    return relevanceScore > 0;
  }).toList();
}
```

#### **文字正規化處理**
```dart
String _normalizeSearchText(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s\-\(\)\.\,\:\;\!\?]'), '') // 保留更多標點符號
      .replaceAll(RegExp(r'\s+'), ' ')                       // 統一空格
      .trim();
}
```

### **📈 排序邏輯**

#### **5種排序選項**
```dart
List<Map<String, dynamic>> _sortTasks(tasks, chatProvider) {
  sortedTasks.sort((a, b) {
    switch (chatProvider.currentSortBy) {
      case 'relevance':        // 相關性排序（搜尋時）
        final relevanceA = a['_relevance'] ?? 0;
        final relevanceB = b['_relevance'] ?? 0;
        comparison = relevanceB.compareTo(relevanceA); // 降序
        break;
        
      case 'updated_time':     // 更新時間
        final timeA = DateTime.parse(a['updated_at'] ?? DateTime.now().toString());
        final timeB = DateTime.parse(b['updated_at'] ?? DateTime.now().toString());
        comparison = timeB.compareTo(timeA); // 降序
        break;
        
      case 'status_order':     // 狀態順序
        final soA = (a['sort_order'] as num?)?.toInt() ?? 999;
        final soB = (b['sort_order'] as num?)?.toInt() ?? 999;
        comparison = soA.compareTo(soB);
        break;
        
      case 'applicant_count':  // 應徵人數
        final countA = (_applicationsByTask[a['id']?.toString()] ?? []).length;
        final countB = (_applicationsByTask[b['id']?.toString()] ?? []).length;
        comparison = countA.compareTo(countB);
        break;
        
      case 'status_id':        // 狀態ID
        final statusIdA = int.tryParse(a['status_id']?.toString() ?? '0') ?? 0;
        final statusIdB = int.tryParse(b['status_id']?.toString() ?? '0') ?? 0;
        comparison = statusIdA.compareTo(statusIdB);
        break;
    }
    
    // 穩定次序：tie-breakers
    if (comparison == 0) {
      // 次鍵1：updated_at desc
      // 次鍵2：id desc
    }
    
    return chatProvider.sortAscending ? comparison : -comparison;
  });
}
```

### **🎛️ 篩選邏輯**

#### **多維度篩選**
```dart
// 位置篩選（支援跨位置搜尋）
final matchLocation = chatProvider.crossLocationSearch ||
    chatProvider.selectedLocations.isEmpty ||
    chatProvider.selectedLocations.contains(locationVal);

// 狀態篩選
final status = _displayStatus(task);
final matchStatus = chatProvider.selectedStatuses.isEmpty ||
    chatProvider.selectedStatuses.contains(status);
```

### **🔄 重設邏輯**

#### **Provider 統一管理**
```dart
// 通過 ChatListProvider 統一重設
chatProvider.resetFilters(); // 重設所有篩選條件

// Provider 內部實現
void resetFilters() {
  _searchQueries[_currentTabIndex] = '';
  _selectedLocations[_currentTabIndex]?.clear();
  _selectedStatuses[_currentTabIndex]?.clear();
  _currentSortBy[_currentTabIndex] = 'updated_time';
  _sortAscending[_currentTabIndex] = false;
  _hasManualSortOverride[_currentTabIndex] = false;
  _emit('criteria');
}
```

---

## 🔍 **My Works Widget 分析**

### **📊 資料取得邏輯**

#### **1. 分頁式資料管理**
```dart
static const int _pageSize = 10;
final PagingController<int, Map<String, dynamic>> _pagingController =
    PagingController(firstPageKey: 0);

// 分頁載入監聽
_pagingController.addPageRequestListener((offset) {
  _fetchMyWorksPage(offset);
});
```

#### **2. 多層快取策略**
```dart
List<Map<String, dynamic>> _composeMyWorks(TaskService service, int? currentUserId) {
  // 優先級1：ChatListProvider 快取
  if (chatProvider.myWorksApplications.isNotEmpty) {
    apps = List<Map<String, dynamic>>.from(chatProvider.myWorksApplications);
    debugPrint('✅ 使用 ChatListProvider 快取');
  } 
  // 優先級2：ChatCacheManager 快取
  else if (chatProvider.isCacheReadyForTab(TAB_MY_WORKS)) {
    apps = List<Map<String, dynamic>>.from(chatProvider.cacheManager.myWorksCache);
    debugPrint('✅ 使用 ChatCacheManager 快取');
  } 
  // 優先級3：TaskService 資料
  else {
    apps = service.myApplications;
    debugPrint('📡 使用 TaskService 資料');
  }
}
```

#### **3. 資料載入流程**
```dart
Future<void> _fetchMyWorksPage(int offset) async {
  // 1. 檢查快取資料
  if (chatProvider.isCacheReadyForTab(TAB_MY_WORKS)) {
    final cachedData = chatProvider.cacheManager.myWorksCache;
  } else {
    // 2. 調用 API 載入
    await taskService.loadMyApplications(currentUserId);
  }
  
  // 3. 組合資料
  final allTasks = _composeMyWorks(taskService, currentUserId);
  
  // 4. 應用篩選和排序
  final filtered = _filterTasks(allTasks, chatProvider);
  final sorted = _sortTasks(filtered, chatProvider);
  
  // 5. 分頁處理
  final slice = sorted.sublist(start, end);
  final hasMore = end < sorted.length;
  
  if (hasMore) {
    _pagingController.appendPage(slice, end);
  } else {
    _pagingController.appendLastPage(slice);
  }
}
```

### **🔍 查詢邏輯**

#### **多欄位搜尋（無相關性評分）**
```dart
List<Map<String, dynamic>> _filterTasks(tasks, chatProvider) {
  return tasks.where((task) {
    final normalizedQuery = _normalizeSearchText(rawQuery);
    
    // 多欄位匹配（任一命中即可）
    bool matchQuery = true;
    if (hasSearchQuery) {
      matchQuery = nTitle.contains(normalizedQuery) ||
          nDesc.contains(normalizedQuery) ||
          nMsg.contains(normalizedQuery) ||      // 最新訊息
          nCreator.contains(normalizedQuery) ||  // 創建者名稱
          nLoc.contains(normalizedQuery) ||
          nLang.contains(normalizedQuery) ||
          nStatus.contains(normalizedQuery);
    }
    
    return matchQuery;
  }).toList();
}
```

### **📈 排序邏輯**

#### **4種排序選項**
```dart
List<Map<String, dynamic>> _sortTasks(tasks, chatProvider) {
  sortedTasks.sort((a, b) {
    switch (chatProvider.currentSortBy) {
      case 'status_order':     // 狀態順序（主要）
        final soA = (a['sort_order'] as num?)?.toInt() ?? 999;
        final soB = (b['sort_order'] as num?)?.toInt() ?? 999;
        if (soA != soB) {
          comparison = soA.compareTo(soB);
          break;
        }
        // 次序：updated_at DESC
        final timeA = DateTime.parse(a['updated_at'] ?? DateTime.now().toString());
        final timeB = DateTime.parse(b['updated_at'] ?? DateTime.now().toString());
        comparison = timeB.compareTo(timeA);
        break;
        
      case 'updated_time':     // 更新時間
        final timeA = DateTime.parse(a['updated_at'] ?? DateTime.now().toString());
        final timeB = DateTime.parse(b['updated_at'] ?? DateTime.now().toString());
        comparison = timeA.compareTo(timeB);
        break;
        
      case 'status_id':        // 狀態ID
        final statusIdA = int.tryParse(a['status_id']?.toString() ?? '0') ?? 0;
        final statusIdB = int.tryParse(b['status_id']?.toString() ?? '0') ?? 0;
        comparison = statusIdA.compareTo(statusIdB);
        break;
        
      case 'status_code':      // 狀態代碼
        final statusA = a['status_code'] ?? '';
        final statusB = b['status_code'] ?? '';
        comparison = statusA.compareTo(statusB);
        break;
    }
    
    return chatProvider.sortAscending ? comparison : -comparison;
  });
}
```

### **🎛️ 篩選邏輯**

#### **簡化篩選**
```dart
// 位置篩選（始終尊重使用者選擇）
final matchLocation = chatProvider.selectedLocations.isEmpty ||
    chatProvider.selectedLocations.contains(location);

// 狀態篩選
final matchStatus = chatProvider.selectedStatuses.isEmpty ||
    chatProvider.selectedStatuses.contains(statusDisplay);
```

### **🔄 重設邏輯**

#### **Provider 統一管理（同 Posted Tasks）**
```dart
// 使用相同的 ChatListProvider.resetFilters()
chatProvider.resetFilters();
```

---

## 📊 **對比分析**

### **🔍 相似點**

| 項目 | Posted Tasks | My Works | 一致性 |
|------|-------------|----------|--------|
| **狀態管理** | ChatListProvider | ChatListProvider | ✅ 一致 |
| **重設機制** | Provider.resetFilters() | Provider.resetFilters() | ✅ 一致 |
| **文字正規化** | _normalizeSearchText() | _normalizeSearchText() | ✅ 一致 |
| **篩選架構** | 位置+狀態篩選 | 位置+狀態篩選 | ✅ 一致 |

### **🚨 差異點**

| 項目 | Posted Tasks | My Works | 影響 |
|------|-------------|----------|------|
| **資料載入** | 一次性載入 | 分頁載入 | ⚠️ 架構不同 |
| **搜尋邏輯** | 相關性評分 | 簡單匹配 | ❌ 功能差異 |
| **排序選項** | 5種（含相關性） | 4種（無相關性） | ⚠️ 選項不同 |
| **快取策略** | 單層快取 | 三層快取 | ❌ 複雜度不同 |
| **搜尋欄位** | 6個欄位 | 7個欄位（含訊息） | ⚠️ 範圍不同 |

---

## 🎯 **問題識別**

### **🔥 高優先級問題**

#### **1. 搜尋功能不一致** ❌
```dart
// Posted Tasks - 有相關性評分
if (nTitle.contains(normalizedQuery)) relevanceScore += 3;
task['_relevance'] = relevanceScore;

// My Works - 無相關性評分
matchQuery = nTitle.contains(normalizedQuery) || nDesc.contains(normalizedQuery);
```

#### **2. 資料載入策略差異** ❌
```dart
// Posted Tasks - 一次性載入
final result = await TaskService().fetchPostedTasksAggregated(limit: 50);

// My Works - 分頁載入
final slice = sorted.sublist(start, end);
_pagingController.appendPage(slice, end);
```

#### **3. 快取策略複雜度不同** ❌
```dart
// Posted Tasks - 簡單快取
_allTasks.clear();
_allTasks.addAll(result.tasks);

// My Works - 三層快取
if (chatProvider.myWorksApplications.isNotEmpty) { /* 優先級1 */ }
else if (chatProvider.isCacheReadyForTab()) { /* 優先級2 */ }
else { /* 優先級3 */ }
```

### **🟡 中優先級問題**

#### **4. 排序選項不統一** ⚠️
```dart
// Posted Tasks 獨有
case 'relevance':        // 相關性排序
case 'applicant_count':  // 應徵人數

// My Works 獨有
case 'status_code':      // 狀態代碼
```

#### **5. 搜尋欄位範圍不同** ⚠️
```dart
// Posted Tasks: title, description, hashtags, location, language, status
// My Works: title, description, latest_message, creator_name, location, language, status
```

---

## 🚀 **優化建議**

### **階段一：統一搜尋邏輯** 🔥
```dart
// 建議為 My Works 添加相關性評分
class UnifiedSearchLogic {
  static List<Map<String, dynamic>> searchWithRelevance(
    List<Map<String, dynamic>> tasks,
    String query, {
    Map<String, int> fieldWeights = const {
      'title': 3,
      'hashtags': 2,
      'description': 1,
      'latest_message': 1,
      'creator_name': 1,
      'location': 1,
      'language': 1,
      'status': 1,
    },
  }) {
    // 統一的相關性評分邏輯
  }
}
```

### **階段二：統一資料載入策略** 🔥
```dart
// 建議 Posted Tasks 也採用分頁載入
class UnifiedDataLoader {
  static Future<void> loadTasksWithPagination({
    required String taskType, // 'posted' or 'my_works'
    required int offset,
    required int limit,
  }) {
    // 統一的分頁載入邏輯
  }
}
```

### **階段三：簡化快取策略** 🟡
```dart
// 建議統一使用 ChatListProvider 作為主要快取
class UnifiedCacheStrategy {
  static List<Map<String, dynamic>> getTasksFromCache(
    ChatListProvider provider,
    int tabIndex,
  ) {
    // 統一的快取獲取邏輯
  }
}
```

### **階段四：統一排序選項** 🟡
```dart
// 建議統一排序選項定義
enum UnifiedSortOption {
  relevance('relevance'),      // 兩者都支援
  updatedTime('updated_time'), // 兩者都支援
  statusOrder('status_order'), // 兩者都支援
  applicantCount('applicant_count'), // Posted Tasks 專用
  statusId('status_id'),       // 兩者都支援
}
```

---

## 📈 **預期效果**

### **統一化後的優勢**
- **用戶體驗一致性**：搜尋和排序行為統一
- **代碼維護性**：減少重複邏輯，統一架構
- **性能優化**：統一的快取和載入策略
- **功能完整性**：兩個分頁都支援相關性搜尋

### **實施優先級**
1. **🔥 立即實施**：統一搜尋邏輯（相關性評分）
2. **🔥 下個版本**：統一資料載入策略（分頁載入）
3. **🟡 中期規劃**：簡化快取策略
4. **🟡 長期優化**：統一排序選項和 UI 組件

---

## 📝 **總結**

兩個 Widget 在架構設計上有明顯差異：
- **Posted Tasks** 偏向簡單直接，一次性載入
- **My Works** 偏向複雜精細，分頁載入 + 多層快取

建議優先統一搜尋邏輯和資料載入策略，以提供一致的用戶體驗和更好的維護性。

---

**分析日期**：2025-01-18  
**分析人員**：AI Assistant  
**狀態**：✅ 完成分析  
**下一步**：等待實施決策
