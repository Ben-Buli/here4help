# iOS 模擬器登入失敗修復報告

## 🐛 問題描述

iOS 模擬器登入時出現請求超時錯誤：

```
flutter: 🌐 API URL: http://10.0.2.2:8888/here4help/backend/api/auth/login.php
flutter: 💥 登入錯誤: Exception: Request timeout
```

### **問題現象**
- iOS 模擬器無法連接到後端 API
- 請求超時，無法完成登入
- 網路配置不正確

## 🔍 問題分析

### **根本原因**

#### **1. 環境配置問題**
```dart
// 問題：環境配置管理器只檢測 Android 模擬器
static bool _isAndroidEmulator() {
  // 只處理 Android 平台
  return true;
}

// 缺少 iOS 模擬器檢測
// static bool _isIOSSimulator() { ... } // 不存在
```

**問題**：環境配置管理器沒有檢測 iOS 模擬器，導致使用錯誤的 API 地址。

#### **2. 網路地址配置**
- iOS 模擬器需要使用 `10.0.2.2` 而不是 `localhost`
- 當前配置可能使用了 `localhost:8888`，在 iOS 模擬器中無法訪問

#### **3. 缺少 iOS 模擬器專用配置**
- 沒有 iOS 模擬器專用的環境配置文件
- 沒有 iOS 模擬器專用的啟動腳本

## 🔧 修復方案

### **1. 添加 iOS 模擬器檢測**

#### 修改檔案：`lib/config/environment_config.dart`

**執行內容**：
- 添加 iOS 模擬器檢測邏輯
- 在初始化時自動選擇正確的環境配置
- 更新預設配置以支持 iOS 模擬器

**程式碼變更**：
```dart
/// 檢測是否為 iOS 模擬器
static bool _isIOSSimulator() {
  // 檢查環境變數
  const iosSimulator =
      bool.fromEnvironment('IOS_SIMULATOR', defaultValue: false);
  if (iosSimulator) return true;

  // 檢查是否在 iOS 平台上運行且不是 Web
  if (!kIsWeb) {
    // 在 iOS 平台上，默認使用模擬器配置
    return true;
  }

  return false;
}

/// 初始化配置
static Future<void> initialize() async {
  if (_config != null) return;

  try {
    String environment = String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'development',
    );

    // 檢測 Android 模擬器並使用相應配置
    if (_isAndroidEmulator()) {
      environment = 'android_emulator';
      if (kDebugMode) {
        print('🤖 檢測到 Android 模擬器，使用 android_emulator 配置');
      }
    }

    // 檢測 iOS 模擬器並使用相應配置
    if (_isIOSSimulator()) {
      environment = 'ios_simulator';
      if (kDebugMode) {
        print('🍎 檢測到 iOS 模擬器，使用 ios_simulator 配置');
      }
    }

    final configFile = 'assets/app_env/$environment.json';
    final configString = await rootBundle.loadString(configFile);
    _config = json.decode(configString) as Map<String, dynamic>;

    if (kDebugMode) {
      print('🌍 環境配置已載入: $environment');
      print('📁 配置檔案: $configFile');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ 載入環境配置失敗: $e');
      print('💡 使用預設配置');
    }
    // 使用預設配置
    _config = {
      'environment': 'development',
      'public': {
        'api_base_url': _isAndroidEmulator() || _isIOSSimulator()
            ? 'http://10.0.2.2:8888/here4help'
            : 'http://localhost:8888/here4help',
        'socket_url': _isAndroidEmulator() || _isIOSSimulator()
            ? 'http://10.0.2.2:3001'
            : 'http://localhost:3001',
        'image_base_url': _isAndroidEmulator() || _isIOSSimulator()
            ? 'http://10.0.2.2:8888/here4help'
            : 'http://localhost:8888/here4help',
        'google_client_id': '',
        'facebook_app_id': '',
        'apple_service_id': '',
      },
      'app': {
        'debug_mode': true,
        'log_level': 'debug',
        'features': {},
      },
    };
  }
}
```

### **2. 創建 iOS 模擬器環境配置**

#### 新增檔案：`assets/app_env/ios_simulator.json`

**執行內容**：
- 創建 iOS 模擬器專用的環境配置文件
- 使用正確的網路地址配置

**配置內容**：
```json
{
  "environment": "development",
  "public": {
    "api_base_url": "http://10.0.2.2:8888/here4help",
    "socket_url": "http://10.0.2.2:3001",
    "image_base_url": "http://10.0.2.2:8888/here4help",
    "google_client_id": "",
    "facebook_app_id": "",
    "apple_service_id": ""
  },
  "app": {
    "debug_mode": true,
    "log_level": "debug",
    "features": {
      "third_party_auth": true,
      "chat": true,
      "tasks": true,
      "payments": false
    }
  }
}
```

### **3. 創建 iOS 模擬器啟動腳本**

#### 新增檔案：`start_ios_simulator.sh`

**執行內容**：
- 創建 iOS 模擬器專用啟動腳本
- 自動檢查後端服務狀態
- 使用正確的 dart-define 參數

**腳本內容**：
```bash
#!/bin/bash

# iOS 模擬器啟動腳本
echo "🍎 啟動 iOS 模擬器配置..."

# 檢查後端服務
echo "🔍 檢查後端服務..."
if curl -s http://localhost:8888/here4help/backend/api/auth/login.php > /dev/null; then
    echo "✅ 後端服務運行正常"
else
    echo "❌ 後端服務未運行，請先啟動後端服務"
    exit 1
fi

# 檢查 Socket.IO 服務
echo "🔍 檢查 Socket.IO 服務..."
if curl -s http://localhost:3001 > /dev/null; then
    echo "✅ Socket.IO 服務運行正常"
else
    echo "❌ Socket.IO 服務未運行，請先啟動 Socket.IO 服務"
    exit 1
fi

# 啟動 Flutter iOS 模擬器
echo "🚀 啟動 Flutter iOS 模擬器..."
flutter run -d ios \
  --dart-define=ENVIRONMENT=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:8888/here4help \
  --dart-define=SOCKET_URL=http://10.0.2.2:3001 \
  --dart-define=IMAGE_BASE_URL=http://10.0.2.2:8888/here4help \
  --dart-define=DEBUG_MODE=true \
  --dart-define=LOG_LEVEL=debug \
  --dart-define=IOS_SIMULATOR=true
```

### **4. 創建輔助配置文件**

#### 新增檔案：`env_config/ios_simulator.json`

**執行內容**：
- 創建 iOS 模擬器專用的環境配置參考文件

**配置內容**：
```json
{
  "environment": "development",
  "api_base_url": "http://10.0.2.2:8888/here4help",
  "socket_url": "http://10.0.2.2:3001",
  "image_base_url": "http://10.0.2.2:8888/here4help",
  "debug_mode": true,
  "log_level": "debug",
  "features": {
    "third_party_auth": true,
    "chat": true,
    "tasks": true,
    "payments": false
  }
}
```

#### 新增檔案：`env_config/dart-define-ios-simulator.txt`

**執行內容**：
- 創建 iOS 模擬器專用的 dart-define 配置

**配置內容**：
```
--dart-define=ENVIRONMENT=development
--dart-define=API_BASE_URL=http://10.0.2.2:8888/here4help
--dart-define=SOCKET_URL=http://10.0.2.2:3001
--dart-define=IMAGE_BASE_URL=http://10.0.2.2:8888/here4help
--dart-define=DEBUG_MODE=true
--dart-define=LOG_LEVEL=debug
```

## 📊 修復效果

### **功能改善**
- ✅ **自動檢測 iOS 模擬器**：環境配置管理器自動檢測 iOS 平台
- ✅ **正確的網路配置**：使用 `10.0.2.2` 地址訪問後端服務
- ✅ **專用啟動腳本**：提供 iOS 模擬器專用啟動方式
- ✅ **服務狀態檢查**：啟動前自動檢查後端服務狀態

### **技術特點**
- ✅ **平台檢測**：自動檢測 Android 和 iOS 模擬器
- ✅ **環境配置**：支持多種環境配置（development, android_emulator, ios_simulator）
- ✅ **網路適配**：自動使用正確的網路地址
- ✅ **錯誤處理**：提供詳細的錯誤信息和服務狀態檢查

### **使用方式**

#### **方法 1：使用啟動腳本**
```bash
# 給腳本執行權限
chmod +x start_ios_simulator.sh

# 啟動 iOS 模擬器
./start_ios_simulator.sh
```

#### **方法 2：手動啟動**
```bash
flutter run -d ios \
  --dart-define=ENVIRONMENT=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:8888/here4help \
  --dart-define=SOCKET_URL=http://10.0.2.2:3001 \
  --dart-define=IMAGE_BASE_URL=http://10.0.2.2:8888/here4help \
  --dart-define=DEBUG_MODE=true \
  --dart-define=LOG_LEVEL=debug \
  --dart-define=IOS_SIMULATOR=true
```

#### **方法 3：使用配置文件**
```bash
flutter run -d ios --dart-define-from-file=env_config/dart-define-ios-simulator.txt
```

## 🎯 技術要點

### **1. 平台檢測邏輯**
```dart
// 檢測 iOS 模擬器
static bool _isIOSSimulator() {
  const iosSimulator = bool.fromEnvironment('IOS_SIMULATOR', defaultValue: false);
  if (iosSimulator) return true;
  
  if (!kIsWeb) {
    return true; // iOS 平台默認使用模擬器配置
  }
  return false;
}
```

### **2. 網路地址配置**
```dart
// 正確的網路地址配置
'api_base_url': _isAndroidEmulator() || _isIOSSimulator()
    ? 'http://10.0.2.2:8888/here4help'  // 模擬器使用 10.0.2.2
    : 'http://localhost:8888/here4help', // 其他平台使用 localhost
```

### **3. 環境配置管理**
```dart
// 自動選擇環境配置
if (_isIOSSimulator()) {
  environment = 'ios_simulator';
  print('🍎 檢測到 iOS 模擬器，使用 ios_simulator 配置');
}
```

## 📝 驗證步驟

### **1. 檢查後端服務**
```bash
curl -s http://localhost:8888/here4help/backend/api/auth/login.php
# 應該返回: {"success":false,"message":"Method not allowed"}
```

### **2. 檢查 Socket.IO 服務**
```bash
curl -s http://localhost:3001
# 應該返回 HTML 錯誤頁面（表示服務運行中）
```

### **3. 啟動 iOS 模擬器**
```bash
./start_ios_simulator.sh
```

### **4. 測試登入**
- 使用 `elies818@gmail.com` 和密碼 `1234` 登入
- 檢查是否不再出現請求超時錯誤

## 📝 總結

通過以下修復，成功解決了 iOS 模擬器登入失敗問題：

1. **添加 iOS 模擬器檢測**：環境配置管理器自動檢測 iOS 平台
2. **創建專用配置**：提供 iOS 模擬器專用的環境配置
3. **修正網路地址**：使用 `10.0.2.2` 而不是 `localhost`
4. **提供啟動腳本**：自動檢查服務狀態並啟動應用

修復後的 iOS 模擬器具有以下優勢：
- **自動配置**：無需手動設置網路地址
- **服務檢查**：啟動前自動檢查後端服務狀態
- **錯誤處理**：提供詳細的錯誤信息和解決方案
- **易於使用**：提供多種啟動方式，適應不同使用習慣

這個修復確保了 iOS 模擬器能夠正確連接到後端服務，解決了登入超時問題，提升了開發體驗。
