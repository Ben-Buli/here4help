# 任務大廳頁面 Edit Icon 添加總結

## 需求描述
在 `/task` 任務大廳頁面的 AppBar 右上角新增一個 Edit Icon，點擊後會前往 `/task/create` 頁面。

## 架構分析
根據你的 Flutter app 架構：
- **Safe Area** > **AppScaffold()** + **NavBottom** > 包裹著頁面的內容
- 由 `shellPages.dart` 設定每個路由對應的頁面包含哪些佈局元件（例如：appbar, title, backArrow）

## 解決方案

### 1. 修改 shell_pages.dart 配置
在 `/task` 路由配置中添加 `actionsBuilder`：

```dart
{
  'path': '/task',
  'child': const TaskListPage(),
  'title': 'Task',
  'showBottomNav': true,
  'showBackArrow': true,
  'actionsBuilder': (context) => [
    IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () {
        context.push('/task/create');
      },
    ),
  ],
},
```

### 2. 修改 app_router.dart 路由處理
在 `ShellRoute` 的 `builder` 中添加對 `actionsBuilder` 的支援：

```dart
// 處理 actions
List<Widget>? actions;
if (pageConfig.containsKey('actionsBuilder')) {
  final actionsBuilder = pageConfig['actionsBuilder'] as List<Widget> Function(BuildContext);
  actions = actionsBuilder(context);
} else {
  actions = pageConfig['actions'] ?? AppScaffoldDefaults.defaultActions;
}

return AppScaffold(
  // ... 其他配置
  actions: actions,
  child: child,
);
```

## 技術細節

### 為什麼使用 actionsBuilder 而不是 actions？
1. **Context 問題**：在靜態配置中直接定義 `IconButton` 無法獲取 `BuildContext`
2. **動態生成**：`actionsBuilder` 允許在運行時動態生成 actions，可以訪問 context
3. **靈活性**：未來可以根據不同條件動態生成不同的 actions

### 實現原理
1. **配置層**：在 `shell_pages.dart` 中定義 `actionsBuilder` 函數
2. **路由層**：在 `app_router.dart` 中檢查並執行 `actionsBuilder`
3. **佈局層**：`AppScaffold` 接收並顯示 actions

## 修改文件

### ✅ lib/constants/shell_pages.dart
- 為 `/task` 路由添加 `actionsBuilder` 配置
- 定義 Edit Icon 和導航邏輯

### ✅ lib/router/app_router.dart
- 添加對 `actionsBuilder` 的支援
- 動態生成 actions 並傳遞給 AppScaffold

## 驗證結果
- ✅ Flutter 分析檢查通過
- ✅ iOS 構建成功
- ✅ 架構一致性保持

## 使用方式
現在當用戶訪問 `/task` 頁面時：
1. AppBar 右上角會顯示一個 Edit 圖標
2. 點擊 Edit 圖標會導航到 `/task/create` 頁面
3. 保持了原有的返回箭頭和標題

## 擴展性
這個解決方案可以輕鬆擴展到其他頁面：
- 只需在 `shell_pages.dart` 中添加 `actionsBuilder` 配置
- 支援多個 actions（例如：編輯、刪除、分享等）
- 可以根據用戶權限動態顯示不同的 actions

修改完成時間：2024年12月19日 