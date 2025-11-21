# iOS 真機測試失敗診斷報告

## 🔍 問題分析

根據終端輸出和代碼檢查，發現以下可能的失敗原因：

### 1. **環境配置加載順序問題** ⚠️

**問題**：`environment_config.dart` 會優先從 JSON 文件加載配置，如果成功加載，就會忽略 `dart-define` 傳入的環境變數。

```dart
// lib/config/environment_config.dart:143-145
final configFile = 'assets/app_env/$environment.json';
final configString = await rootBundle.loadString(configFile);
_config = json.decode(configString) as Map<String, dynamic>;
```

**影響**：
- 如果 `development.json` 存在且加載成功，會使用 JSON 文件中的配置
- `dart-define` 傳入的 `API_BASE_URL`、`SOCKET_URL` 等參數會被忽略
- JSON 文件中的 IP 地址可能與當前網絡環境不匹配

**當前狀態**：
- ✅ `development.json` 中的 IP 是 `192.168.1.101`（正確）
- ⚠️ 但如果 IP 改變，需要手動更新 JSON 文件

### 2. **Socket 端口不匹配** ⚠️

**問題**：
- 腳本使用端口 `3000`：`SOCKET_URL="http://$LOCAL_IP:3000"`
- `env_config.dart` 默認值是 `3001`：`defaultValue: 'http://127.0.0.1:3001'`

**影響**：
- 如果 JSON 文件加載失敗，會使用默認配置，導致 Socket 連接失敗

**當前狀態**：
- ✅ Socket 服務器確實在 3000 端口運行（從 `lsof` 輸出確認）
- ✅ `development.json` 中配置的是 3000（正確）

### 3. **網絡地址轉換邏輯不完整** ⚠️

**問題**：`_getNetworkAddress()` 只處理 Android 模擬器，不處理 iOS 真機的情況。

```dart
// lib/config/environment_config.dart:81-92
static String _getNetworkAddress(String baseUrl) {
  try {
    final uri = Uri.parse(baseUrl);
    if (defaultTargetPlatform == TargetPlatform.android &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      return uri.replace(host: '10.0.2.2').toString();
    }
    return baseUrl; // iOS 真機不會轉換
  } catch (_) {
    return baseUrl;
  }
}
```

**影響**：
- 如果使用默認配置（`localhost` 或 `127.0.0.1`），iOS 真機無法訪問

### 4. **CocoaPods 配置警告** ⚠️

**問題**：CocoaPods 警告項目已有自定義配置，可能影響構建。

```
[!] CocoaPods did not set the base configuration of your project because your project already has a custom config set.
```

**影響**：
- 可能導致構建失敗或運行時錯誤
- 需要檢查 Xcode 項目配置

### 5. **MAMP 外部訪問配置** ⚠️

**問題**：MAMP 默認可能只監聽 `localhost`，不允許外部訪問。

**檢查結果**：
- ✅ MAMP 正在監聽 `*:8888`（從 `lsof` 輸出確認），應該可以接受外部連接
- ⚠️ 但需要確認防火牆設置

## 🔧 修復建議

### 修復 1：改進環境配置加載邏輯

修改 `environment_config.dart`，讓 `dart-define` 參數優先於 JSON 文件：

```dart
// 優先使用 dart-define 參數
final apiBaseUrl = _getEnvValue('API_BASE_URL');
final socketUrl = _getEnvValue('SOCKET_URL');
final imageBaseUrl = _getEnvValue('IMAGE_BASE_URL');

if (apiBaseUrl.isNotEmpty || socketUrl.isNotEmpty || imageBaseUrl.isNotEmpty) {
  // 使用 dart-define 參數
  _config = {
    'environment': environment,
    'public': {
      'api_base_url': apiBaseUrl.isNotEmpty ? apiBaseUrl : _config?['public']?['api_base_url'],
      'socket_url': socketUrl.isNotEmpty ? socketUrl : _config?['public']?['socket_url'],
      'image_base_url': imageBaseUrl.isNotEmpty ? imageBaseUrl : _config?['public']?['image_base_url'],
      // ... 其他配置
    },
  };
} else {
  // 回退到 JSON 文件
  final configFile = 'assets/app_env/$environment.json';
  // ... 加載 JSON
}
```

### 修復 2：改進網絡地址轉換邏輯

修改 `_getNetworkAddress()`，支持 iOS 真機：

```dart
static String _getNetworkAddress(String baseUrl) {
  try {
    final uri = Uri.parse(baseUrl);
    // iOS 真機：如果使用 localhost/127.0.0.1，需要替換為實際 IP
    if (defaultTargetPlatform == TargetPlatform.iOS && 
        !kIsWeb &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      // 嘗試從環境變數獲取 IP
      final localIp = _getEnvValue('LOCAL_IP');
      if (localIp.isNotEmpty) {
        return uri.replace(host: localIp).toString();
      }
    }
    // Android 模擬器處理
    if (defaultTargetPlatform == TargetPlatform.android &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      return uri.replace(host: '10.0.2.2').toString();
    }
    return baseUrl;
  } catch (_) {
    return baseUrl;
  }
}
```

### 修復 3：更新腳本添加 LOCAL_IP 環境變數

修改 `run_ios_device.sh`，添加 `LOCAL_IP` 環境變數：

```bash
--dart-define=LOCAL_IP=$LOCAL_IP \
```

### 修復 4：檢查 CocoaPods 配置

檢查 Xcode 項目配置，確保 CocoaPods 配置正確。

## 🧪 測試步驟

1. **檢查網絡連接**：
   ```bash
   # 從真機測試（需要在真機上執行）
   curl http://192.168.1.101:8888/here4help/backend/api/auth/login.php
   ```

2. **檢查 Socket 連接**：
   ```bash
   curl http://192.168.1.101:3000/health
   ```

3. **檢查防火牆**：
   ```bash
   # macOS 防火牆設置
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
   ```

4. **檢查 MAMP 配置**：
   - 確認 MAMP 允許外部訪問
   - 檢查 Apache 配置中的 `Listen` 指令

## 📝 建議的優先修復順序

1. **立即修復**：改進環境配置加載邏輯（修復 1）
2. **重要修復**：改進網絡地址轉換邏輯（修復 2）
3. **可選修復**：更新腳本添加 LOCAL_IP（修復 3）
4. **檢查修復**：CocoaPods 配置（修復 4）

## 🔍 進一步診斷

如果問題仍然存在，請檢查：

1. **真機網絡連接**：
   - 確認真機與開發機器在同一 Wi-Fi 網絡
   - 確認真機可以訪問開發機器的 IP 地址

2. **應用日誌**：
   - 查看 Flutter 應用運行時的日誌
   - 檢查是否有網絡連接錯誤

3. **Xcode 控制台**：
   - 查看 Xcode 控制台的錯誤信息
   - 檢查是否有構建或運行時錯誤

