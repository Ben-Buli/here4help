# ChatListPage 重構文檔

## 📋 重構概要

**重構日期：** 2024年
**重構原因：** ChatListPage 單一檔案過大（4,101 行），維護困難，團隊協作時容易產生衝突
**重構目標：** 模組化、提升可維護性、消除 GlobalKey 依賴

## 🔄 重構前後對比

### 重構前
```
lib/chat/pages/chat_list_page.dart (4,101 行)
├── 搜索篩選邏輯
├── Posted Tasks 功能
├── My Works 功能
├── Tab 控制邏輯
├── 通知管理
├── 快取管理
└── UI 渲染
```

### 重構後
```
lib/chat/
├── providers/
│   └── chat_list_provider.dart          # 狀態管理 (替代 GlobalKey)
├── widgets/
│   ├── search_filter_widget.dart        # 搜索篩選組件
│   ├── posted_tasks_widget.dart         # Posted Tasks 模組
│   ├── my_works_widget.dart             # My Works 模組
│   └── chat_list_task_widget.dart       # Tab 標題組件 (已存在)
└── pages/
    └── chat_list_page.dart              # 主控制器 (~300 行)
```

## 🏗️ 架構設計

### 1. ChatListProvider (狀態管理層)
**職責：**
- 統一管理 TabController
- 處理搜索和篩選狀態
- 管理載入狀態
- 提供狀態變更通知

**替代方案：**
- 🔴 移除：`ChatListPage.globalKey`
- 🟢 新增：`ChatListProvider` with `ChangeNotifier`

### 2. SearchFilterWidget (搜索篩選層)
**職責：**
- 搜索輸入框
- 篩選按鈕
- 排序選項
- 重置功能

### 3. PostedTasksWidget & MyWorksWidget (內容層)
**職責：**
- 獨立的分頁內容管理
- 各自的分頁控制器
- 任務卡片渲染
- 資料載入邏輯

### 4. ChatListPage (協調層)
**職責：**
- 組裝各個模組
- 處理生命週期
- 協調組件間通信

## 🔧 技術實現

### Provider 整合
```dart
// 原本的 GlobalKey 方式
ChatListPage.globalKey.currentState?.switchTab(index)

// 重構後的 Provider 方式
context.read<ChatListProvider>().switchTab(index)
```

### TabController 統一
```dart
// 在 ChatListProvider 中統一管理
class ChatListProvider extends ChangeNotifier {
  late TabController _tabController;
  
  void initializeTabController(TickerProvider vsync) {
    _tabController = TabController(length: 2, vsync: vsync);
  }
}
```

## 📝 遷移指南

### 1. 更新 shell_pages.dart
```dart
// 修改前
'titleWidgetBuilder': (context, data) {
  return ChatListTaskWidget(
    initialTab: ChatListPage.globalKey.currentState?.currentTabIndex ?? 0,
    onTabChanged: (index) {
      final chatListState = ChatListPage.globalKey.currentState;
      if (chatListState != null) {
        chatListState.switchTab(index);
      }
    },
  );
}

// 修改後
'titleWidgetBuilder': (context, data) {
  return Consumer<ChatListProvider>(
    builder: (context, provider, child) {
      return ChatListTaskWidget(
        initialTab: provider.currentTabIndex,
        onTabChanged: (index) {
          provider.switchTab(index);
        },
      );
    },
  );
}
```

### 2. Provider 初始化
```dart
// 在 main.dart 或適當位置添加
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ChatListProvider()),
    // ... 其他 providers
  ],
  child: MyApp(),
)
```

## ⚠️ 破壞性變更

### 影響的檔案
1. `lib/constants/shell_pages.dart` - 需要移除 GlobalKey 依賴
2. `lib/chat/widgets/chat_list_task_widget.dart` - 可能需要微調
3. `lib/chat/providers/chat_providers.dart` - 需要添加新的 Provider

### 資料庫影響
**無影響** - 此次重構僅涉及前端架構調整，不涉及資料庫結構變更

### API 影響
**無影響** - 所有 API 調用邏輯保持不變

## 🧪 測試策略

### 單元測試
- [ ] ChatListProvider 狀態管理測試
- [ ] SearchFilterWidget 功能測試
- [ ] PostedTasksWidget 資料載入測試
- [ ] MyWorksWidget 資料載入測試

### 整合測試
- [ ] Tab 切換功能測試
- [ ] 搜索篩選功能測試
- [ ] Provider 和 Widget 整合測試

### E2E 測試
- [ ] 完整的用戶流程測試
- [ ] 路由切換測試
- [ ] 狀態持久化測試

## 📊 性能影響

### 預期改善
- ✅ **包大小**：模組化後可能的 tree-shaking 優化
- ✅ **編譯速度**：小檔案編譯更快
- ✅ **開發體驗**：熱重載更快，衝突減少

### 潛在風險
- ⚠️ **Provider 開銷**：新增的 Provider 監聽可能有輕微性能影響
- ⚠️ **記憶體使用**：多個 Widget 實例可能增加記憶體使用

## 🚀 部署檢查清單

### 重構前
- [ ] 備份原始 ChatListPage
- [ ] 確認所有功能正常運作
- [ ] 記錄現有的 GlobalKey 使用點

### 重構中
- [ ] 逐步建立新模組
- [ ] 保持功能對等性
- [ ] 更新相關依賴檔案

### 重構後
- [ ] 全功能測試
- [ ] 性能基準測試
- [ ] 團隊代碼審查

## 👥 團隊協作指南

### 文件結構理解
```bash
# 快速定位功能模組
lib/chat/widgets/search_filter_widget.dart     # 搜索相關問題
lib/chat/widgets/posted_tasks_widget.dart      # Posted Tasks 問題
lib/chat/widgets/my_works_widget.dart          # My Works 問題
lib/chat/providers/chat_list_provider.dart     # 狀態管理問題
```

### 開發工作流
1. **功能新增**：確定所屬模組，在對應檔案中開發
2. **Bug 修復**：根據問題類型，定位到具體模組
3. **代碼審查**：按模組分配審查責任

### 注意事項
- 避免在單一檔案中混合多個模組的邏輯
- 新增功能時優先考慮現有模組的擴展性
- 狀態變更務必通過 ChatListProvider 進行

## 📚 相關文檔

- [Provider 使用指南](https://pub.dev/packages/provider)
- [Flutter 架構最佳實踐](https://flutter.dev/docs/development/data-and-backend/state-mgmt)
- [Chat 快取系統說明](./README_CACHE_SYSTEM.md)

---

**重構負責人：** AI Assistant  
**審查狀態：** 待審查  
**完成狀態：** 進行中 (Phase 1: 架構設計完成)
