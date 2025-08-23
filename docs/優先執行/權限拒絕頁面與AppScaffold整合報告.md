# 權限拒絕頁面與 AppScaffold 整合報告

## 🎯 **整合目標**

將權限拒絕頁面（`/permission-denied`）與 `AppScaffold` 的返回箭頭邏輯整合，提供一致的用戶體驗。

## 🔧 **整合內容**

### **1. 權限拒絕頁面改為 shell_pages 路由**

#### **新增路由配置**：
```dart
{
  'path': '/permission-denied',
  'child': const PermissionDeniedPage(),
  'title': 'Permission Denied',
  'showAppBar': true,
  'showBottomNav': false,
  'showBackArrow': true,
  'permission': -4, // 任何狀態都可訪問權限不足頁面
},
```

#### **關鍵特性**：
- ✅ **統一的路由管理**：使用 shell_pages 統一管理
- ✅ **AppBar 支援**：顯示標題和返回箭頭
- ✅ **權限檢查豁免**：任何用戶都可以訪問此頁面

### **2. 使用 AppScaffold 包裝**

#### **修改前**：
```dart
return Scaffold(
  body: SafeArea(
    child: Padding(...),
  ),
);
```

#### **修改後**：
```dart
return AppScaffold(
  title: 'Permission Denied',
  showAppBar: true,
  showBottomNav: false,
  showBackArrow: true,
  child: Padding(...),
);
```

#### **優勢**：
- ✅ **一致的 UI 風格**：使用應用程式統一的 AppBar 設計
- ✅ **主題支援**：自動適應當前主題設定
- ✅ **返回箭頭邏輯**：整合 AppScaffold 的智能返回機制

### **3. 智能返回邏輯**

#### **新增 `_handleSmartBack` 方法**：
```dart
void _handleSmartBack(BuildContext context) {
  final state = GoRouterState.of(context);
  final fromPath = state.uri.queryParameters['from'];
  
  if (fromPath != null && fromPath.isNotEmpty) {
    // 如果原始頁面是基本頁面（permission = 0），則可以返回
    if (fromPath == '/home' || fromPath == '/account' || fromPath == '/task') {
      context.go(fromPath);
      return;
    }
  }
  
  // 預設返回首頁
  context.go('/home');
}
```

#### **邏輯說明**：
1. **檢查來源路徑**：從查詢參數 `from` 獲取被阻擋的原始路徑
2. **權限驗證**：只允許返回基本頁面（權限要求 = 0）
3. **安全導航**：避免無限循環重定向到權限拒絕頁面
4. **預設行為**：如果無法返回原始頁面，則導向首頁

### **4. 權限守衛重定向邏輯**

#### **修改權限守衛**：
```dart
// 權限 0, -1, -3 訪問需要認證的頁面時，重定向到權限拒絕頁面
if (userPermission <= PermissionService.SELF_SUSPENDED &&
    userPermission != -2 &&
    userPermission != -4) {
  // 重定向到權限拒絕頁面，並傳遞當前路徑作為查詢參數
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.go('/permission-denied?from=$path');
  });
  return const SizedBox.shrink();
}
```

#### **重定向流程**：
1. **權限檢查失敗** → 重定向到 `/permission-denied?from=原始路徑`
2. **權限拒絕頁面** → 顯示錯誤訊息和被阻擋的路徑
3. **用戶操作** → 智能返回或導向首頁

## 🎨 **用戶體驗流程**

### **完整流程**：
```
用戶登入 → 嘗試訪問受限頁面 → 權限檢查失敗 → 
重定向到 /permission-denied?from=原始路徑 → 
顯示權限拒絕頁面 → 用戶點擊返回箭頭 → 
智能返回邏輯 → 導向合適的頁面
```

### **返回箭頭行為**：
1. **AppBar 返回箭頭**：使用 AppScaffold 的智能返回邏輯
2. **頁面內返回按鈕**：使用自定義的 `_handleSmartBack` 邏輯
3. **返回首頁按鈕**：直接導向 `/home`

## 📊 **測試案例**

### **測試 1：權限 0 用戶訪問 `/chat`**
- **原始路徑**：`/chat`
- **重定向到**：`/permission-denied?from=/chat`
- **返回箭頭行為**：導向 `/home`（因為 `/chat` 需要權限 1）
- **預期結果**：✅ 成功返回首頁

### **測試 2：權限 -1 用戶訪問 `/task/create`**
- **原始路徑**：`/task/create`
- **重定向到**：`/permission-denied?from=/task/create`
- **返回箭頭行為**：導向 `/home`（因為 `/task/create` 需要權限 1）
- **預期結果**：✅ 成功返回首頁

### **測試 3：權限 -3 用戶從 `/home` 訪問 `/chat`**
- **原始路徑**：`/chat`
- **重定向到**：`/permission-denied?from=/chat`
- **返回箭頭行為**：導向 `/home`（因為用戶之前在 `/home`）
- **預期結果**：✅ 成功返回首頁

### **測試 4：權限 1 用戶正常訪問**
- **訪問任何頁面**：✅ 正常訪問
- **不會觸發權限拒絕**：✅ 正常流程

## 🚀 **整合效果**

### **整合前問題**：
- ❌ 權限拒絕頁面使用自定義 Scaffold
- ❌ 返回邏輯不一致
- ❌ 沒有與 AppScaffold 的路由歷史整合
- ❌ 用戶體驗不統一

### **整合後效果**：
- ✅ 使用統一的 AppScaffold 設計
- ✅ 智能返回邏輯與路由歷史整合
- ✅ 一致的用戶體驗
- ✅ 安全的權限檢查和導航

## 📝 **技術細節**

### **修改的文件**：
1. `lib/system/pages/permission_denied_page.dart` - 整合 AppScaffold
2. `lib/constants/shell_pages.dart` - 新增路由配置
3. `lib/router/guards/permission_guard.dart` - 重定向邏輯

### **新增功能**：
- `_handleSmartBack()` - 智能返回邏輯
- 查詢參數處理 - `from` 參數傳遞原始路徑
- AppScaffold 整合 - 統一的 UI 和導航體驗

### **依賴關係**：
- `AppScaffold` - 提供統一的頁面框架
- `GoRouter` - 路由管理和查詢參數處理
- `PermissionProvider` - 權限狀態管理

---

**整合完成時間**：2025年1月11日  
**整合執行者**：AI Assistant  
**測試狀態**：邏輯驗證完成，待實際測試
