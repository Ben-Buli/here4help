# Token 過期處理使用指南

本指南說明如何在 Here4Help 應用中使用新的 Token 過期處理機制。

## 🎯 概述

我們建立了一個完整的 Token 過期處理系統，包括：

1. **自動攔截**: HTTP 攔截器自動檢測 401 錯誤
2. **統一處理**: AuthErrorHandler 提供統一的登出流程
3. **用戶友好**: 多種用戶通知方式
4. **便捷集成**: Mixin 和 Widget 讓集成變得簡單

## 🔧 核心組件

### 1. AuthErrorHandler
統一的 Token 過期處理服務

```dart
// 手動觸發 Token 過期處理
await AuthErrorHandler.handleTokenExpiry(reason: '手動登出');

// 檢查錯誤是否為 Token 過期
bool isExpired = AuthErrorHandler.isTokenExpiredError(error);

// 顯示通知
AuthErrorHandler.showTokenExpiredNotification(context);
AuthErrorHandler.showTokenExpiredDialog(context);
```

### 2. HttpClientService
自動攔截 HTTP 401 錯誤

```dart
// 無需額外配置，所有 HTTP 請求自動支持
final response = await HttpClientService.get('/api/user/profile');
// 如果返回 401，會自動處理 Token 過期
```

### 3. TokenExpiryMixin
為頁面提供便捷的錯誤處理

```dart
class MyPage extends StatefulWidget {
  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with TokenExpiryMixin {
  void loadUserData() async {
    try {
      final userData = await UserApi.getProfile();
      setState(() => _userData = userData);
    } catch (e) {
      if (handleIfTokenExpired(e)) return; // Token 過期已處理
      // 處理其他錯誤
      showErrorSnackBar('載入失敗: $e');
    }
  }
  
  // 或使用便捷方法
  void loadUserDataEasy() async {
    await handleApiCall(
      apiCall: () => UserApi.getProfile(),
      onSuccess: (data) => setState(() => _userData = data),
      onError: (error) => showErrorSnackBar('載入失敗: $error'),
    );
  }
}
```

### 4. GlobalErrorHandler
全局錯誤捕獲（可選）

```dart
// 在 main.dart 中使用
void main() {
  runApp(
    GlobalErrorHandler(
      child: MyApp(),
    ),
  );
}
```

## 📱 使用場景

### 場景 1: API 調用錯誤處理

```dart
class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TokenExpiryMixin {
  Map<String, dynamic>? _profile;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    
    await handleApiCall(
      apiCall: () => UserApi.getProfile(),
      onSuccess: (profile) {
        setState(() {
          _profile = profile;
          _loading = false;
        });
      },
      onError: (error) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入個人資料失敗: $error')),
        );
      },
      showDialogOnExpiry: true, // Token 過期時顯示對話框
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('個人資料')),
      body: _loading 
        ? Center(child: CircularProgressIndicator())
        : _profile == null
          ? Center(child: Text('無法載入個人資料'))
          : _buildProfileContent(),
    );
  }
}
```

### 場景 2: 手動檢查和處理

```dart
class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with TokenExpiryMixin {
  Future<void> _updateSettings() async {
    try {
      await SettingsApi.update(newSettings);
      showSuccessMessage();
    } catch (error) {
      // 手動檢查 Token 過期
      if (handleIfTokenExpired(error, showDialog: true)) {
        return; // Token 過期已處理，不顯示其他錯誤
      }
      
      // 處理其他類型的錯誤
      if (error.toString().contains('validation')) {
        showValidationError();
      } else {
        showGenericError(error);
      }
    }
  }
}
```

### 場景 3: 全局錯誤處理

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MultiProvider(
      providers: [...],
      child: GlobalErrorHandler(
        onFlutterError: (details) {
          // 自定義錯誤記錄
          print('Flutter 錯誤: ${details.exception}');
        },
        child: MyApp(),
      ),
    ),
  );
}
```

## ⚡ 最佳實踐

### 1. 在重要操作中使用對話框

```dart
// 對於重要操作（如支付、刪除等），使用對話框提醒
if (handleIfTokenExpired(error, showDialog: true)) return;
```

### 2. 批量 API 調用的處理

```dart
Future<void> loadAllData() async {
  final futures = [
    safeApiCall(() => Api.getUserData()),
    safeApiCall(() => Api.getSettings()),
    safeApiCall(() => Api.getNotifications()),
  ];
  
  final results = await Future.wait(futures);
  
  // 檢查結果，null 表示失敗或 Token 過期
  if (results[0] != null) _userData = results[0];
  if (results[1] != null) _settings = results[1];
  if (results[2] != null) _notifications = results[2];
}
```

### 3. 自定義錯誤消息

```dart
try {
  await PaymentApi.processPayment(amount);
} catch (error) {
  if (handleIfTokenExpired(
    error, 
    showDialog: true,
    customMessage: '支付過程中登入過期，請重新登入後再試',
  )) return;
  
  handlePaymentError(error);
}
```

## 🔍 調試

所有 Token 過期處理都會在 Debug 模式下輸出詳細日誌：

```
🚨 [AuthErrorHandler] Token 過期，開始完整登出流程
✅ [AuthErrorHandler] 通知服務已清理
✅ [AuthErrorHandler] 用戶數據已清理
✅ [AuthErrorHandler] 已跳轉到登入頁面
```

## 📝 注意事項

1. **防重複處理**: 系統內建防重複機制，5 秒內不會重複處理同一類型的 Token 過期
2. **狀態檢查**: 所有 UI 操作都會檢查 `mounted` 狀態
3. **錯誤日誌**: 所有錯誤都會被記錄，方便調試
4. **向後兼容**: 現有代碼無需修改即可享受自動 Token 過期處理

## 🎨 自定義

如需自定義行為，可以：

1. 繼承 `AuthErrorHandler` 並覆蓋相關方法
2. 創建自己的 Mixin 基於 `TokenExpiryMixin`
3. 自定義錯誤 Widget 的樣式和內容

這個系統確保了用戶在遇到 Token 過期時能夠得到友好的提示和流暢的重新登入體驗！
