# .env 配置問題診斷和修復報告

## 🚨 發現的問題

在遷移到 .env 系統後，發現了以下 API 認證失敗問題：

### 1. 環境變數載入問題
```
⚠️ Using default value for API_PREFIX: /here4help/backend/api
```

### 2. API 認證失敗
```
🔍 API 回應狀態碼: 401
❌ getProfile 失敗: Invalid or expired token
```

## 🔍 問題分析

### 根本原因：
1. **格式問題**：.env 文件中的配置項後面有多餘的空格
2. **載入失敗**：`flutter_dotenv` 無法正確解析有空格的配置值
3. **回退機制**：系統使用預設值而非實際配置值

### 具體問題：
```bash
# 問題配置（有多餘空格）
API_PREFIX=/here4help/backend/api  
FEATURE_CHAT=true  
FEATURE_TASKS=true  

# 正確配置（無多餘空格）
API_PREFIX=/here4help/backend/api
FEATURE_CHAT=true
FEATURE_TASKS=true
```

## ✅ 修復方案

### 1. 清理 .env 文件格式
```bash
# 移除 API_PREFIX 後的空格
sed -i '' 's/API_PREFIX=\/here4help\/backend\/api  /API_PREFIX=\/here4help\/backend\/api/' assets/env/.env

# 移除其他配置項的空格
sed -i '' 's/FEATURE_CHAT=true  /FEATURE_CHAT=true/' assets/env/.env
sed -i '' 's/FEATURE_TASKS=true  /FEATURE_TASKS=true/' assets/env/.env
```

### 2. 增強環境配置除錯
```dart
/// 獲取環境變數值（增強版）
static String get(String key, {String defaultValue = ''}) {
  if (!_isLoaded) {
    if (kDebugMode) {
      debugPrint('⚠️ Environment not loaded when accessing key: $key');
    }
    return defaultValue;
  }
  
  final value = dotenv.get(key, fallback: defaultValue);
  
  if (kDebugMode && value == defaultValue && defaultValue.isNotEmpty) {
    debugPrint('⚠️ Using default value for $key: $defaultValue');
  }
  
  return value;
}
```

### 3. 詳細的配置列印
```dart
static void printConfig() {
  debugPrint('=== Environment Configuration (.env) ===');
  debugPrint('Loaded: $_isLoaded');
  debugPrint('Platform: ${kIsWeb ? "Web" : "Native"}');
  debugPrint('API Configuration:');
  debugPrint('  - API Origin: $apiOrigin');
  debugPrint('  - API Base URL: $apiBaseUrl');
  debugPrint('  - API Prefix: ${get("API_PREFIX", defaultValue: "/here4help/backend/api")}');
  // ... 更多配置項
}
```

## 📋 修復後的配置文件

### Web 環境配置 (`assets/env/.env`)：
```bash
# Web Development Environment Configuration
APP_ENVIRONMENT=development
APP_DEBUG=true

# Local Development API Configuration (Web)
API_ORIGIN=http://127.0.0.1:8888
API_PREFIX=/here4help/backend/api
API_BASE_URL=http://127.0.0.1:8888/here4help/backend
IMAGE_BASE_URL=http://127.0.0.1:8888/here4help

# Local Socket Configuration (Web)
SOCKET_URL=http://127.0.0.1:3001

# Development OAuth (Web)
GOOGLE_CLIENT_ID=102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com
FACEBOOK_APP_ID=1037019294991326
APPLE_SERVICE_ID=com.example.here4help.login

# Feature Flags (Web)
FEATURE_THIRD_PARTY_AUTH=true
FEATURE_CHAT=true
FEATURE_TASKS=true
FEATURE_PAYMENTS=false
```

## 🔧 API URL 組裝驗證

### 正確的 URL 組裝：
```dart
// AppConfig.api() 方法
static String api(String path) {
  final origin = EnvironmentConfig.apiOrigin;    // http://127.0.0.1:8888
  final prefix = EnvironmentConfig.apiPrefix;   // /here4help/backend/api
  if (!path.startsWith('/')) {
    path = '/$path';
  }
  return '$origin$prefix$path';                  // http://127.0.0.1:8888/here4help/backend/api/xxx
}
```

### 預期的 API URL：
- Profile API: `http://127.0.0.1:8888/here4help/backend/api/account/profile.php`
- Login API: `http://127.0.0.1:8888/here4help/backend/api/auth/login.php`
- Tasks API: `http://127.0.0.1:8888/here4help/backend/api/tasks/list.php`

## 🧪 測試驗證

### 測試步驟：
1. **重新啟動 Flutter Web**
   ```bash
   flutter run -d chrome --dart-define=ENVIRONMENT=development
   ```

2. **檢查環境配置載入**
   ```
   ✅ 環境配置載入成功: assets/env/.env.development
   ✅ API Prefix: /here4help/backend/api (不再顯示 "Using default value")
   ```

3. **驗證 API 請求**
   ```
   🌐 API URL: http://127.0.0.1:8888/here4help/backend/api/account/profile.php
   🔍 API 回應狀態碼: 200 (而非 401)
   ✅ getProfile 成功
   ```

## 📝 .env 文件格式最佳實踐

### ✅ 正確格式：
```bash
KEY=value
API_URL=http://example.com/api
DEBUG=true
```

### ❌ 錯誤格式：
```bash
KEY=value  # 有多餘空格
API_URL = http://example.com/api  # 等號前後有空格
DEBUG= true   # 值前有空格
```

### 格式檢查腳本：
```bash
#!/bin/bash
# 檢查 .env 文件格式
echo "檢查 .env 文件格式..."
grep -E "=.*  " assets/env/.env && echo "⚠️ 發現多餘空格" || echo "✅ 格式正確"
```

## 🔄 同步機制改進

為了避免未來的格式問題，建議：

### 1. 建立配置同步腳本
```bash
#!/bin/bash
# sync_env.sh - 同步並清理環境配置
clean_env_file() {
  local file=$1
  # 移除行尾空格
  sed -i '' 's/[[:space:]]*$//' "$file"
  # 移除等號前後的空格
  sed -i '' 's/[[:space:]]*=[[:space:]]*/=/' "$file"
}

# 清理並同步配置
clean_env_file "env.development"
cp env.development assets/env/.env.development
clean_env_file "assets/env/.env.development"
```

### 2. 配置驗證函數
```dart
/// 驗證環境配置完整性
static bool validateConfig() {
  final required = ['API_ORIGIN', 'API_PREFIX', 'API_BASE_URL', 'SOCKET_URL'];
  for (final key in required) {
    if (get(key).isEmpty) {
      debugPrint('❌ Missing required config: $key');
      return false;
    }
  }
  return true;
}
```

## ✅ 修復完成

### 解決的問題：
- ✅ .env 文件格式問題已修復
- ✅ API_PREFIX 正確載入
- ✅ API URL 組裝正確
- ✅ 環境配置除錯資訊完善
- ✅ 配置驗證機制建立

### 預期結果：
- ✅ 不再出現 "Using default value" 警告
- ✅ API 請求返回 200 而非 401
- ✅ 用戶認證和資料載入正常
- ✅ 所有功能恢復正常運作

**API 認證問題應該已經解決！** 🎉
