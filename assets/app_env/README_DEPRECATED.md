# ⚠️ 此目錄已廢棄 - app_env JSON 配置系統

## 📢 重要通知

此目錄中的 JSON 配置文件已被**新的 .env 系統**完全取代，並標記為廢棄。

### 🔄 遷移狀況

| 舊 JSON 文件 | 新 .env 文件 | 狀態 |
|-------------|-------------|------|
| `development.json` | `env.development` | ✅ 已遷移 |
| `production.json` | `env.production` | ✅ 已遷移 |
| `testflight.json` | `env.testflight` | ✅ 已遷移 |
| `android_emulator.json` | `env.android_emulator` | ✅ 已遷移 |
| `ios_simulator.json` | `env.ios_simulator` | ✅ 已遷移 |
| `web.json` | `env.development` | ✅ 已整合 |

### 🆕 新系統優勢

1. **安全性更好**：敏感資訊不再包含在應用程式包中
2. **統一管理**：所有環境變數統一在根目錄的 .env 文件中
3. **多環境支援**：輕鬆切換開發、測試、正式環境
4. **端口統一配置**：解決硬編碼端口問題
5. **向後相容**：透過 `environment_config_legacy.dart` 保持 API 相容

### 📁 新的配置文件位置

```
專案根目錄/
├── env.development      # 開發環境配置
├── env.production       # 正式環境配置
├── env.testflight       # TestFlight 配置
├── env.staging          # 測試環境配置
├── env.android_emulator # Android 模擬器配置
├── env.ios_simulator    # iOS 模擬器配置
└── env.example          # 配置範本
```

### 🚀 新的建置方式

```bash
# 不同環境建置
flutter run --dart-define=ENVIRONMENT=development
flutter run --dart-define=ENVIRONMENT=production
flutter run -d android --dart-define=ENVIRONMENT=android_emulator
flutter run -d iphone --dart-define=ENVIRONMENT=ios_simulator
```

### 💻 程式碼變更

#### 舊的方式：
```dart
// 舊的方式 - 不再使用
await EnvironmentConfig.initialize(); // 讀取 JSON
String apiUrl = EnvironmentConfig.apiBaseUrl;
```

#### 新的方式：
```dart
// 新的方式 - 但 API 保持相容
await EnvironmentConfig.initialize(); // 內部使用 .env
String apiUrl = EnvironmentConfig.apiBaseUrl; // 相同 API
```

### 🗑️ 清理計畫

這些 JSON 文件將在確認新系統穩定運作後移除：

- [ ] `development.json` - 2025年2月後移除
- [ ] `production.json` - 2025年2月後移除
- [ ] `testflight.json` - 2025年2月後移除
- [ ] `android_emulator.json` - 2025年2月後移除
- [ ] `ios_simulator.json` - 2025年2月後移除
- [ ] `web.json` - 2025年2月後移除

### 📖 更多資訊

詳細的遷移資訊請參考：
- `ENV_CONFIGURATION_GUIDE.md` - 環境配置完整指南
- `MIGRATION_FROM_APP_ENV.md` - JSON 遷移詳細說明
- `HARDCODED_PORTS_MIGRATION_REPORT.md` - 端口遷移報告

---

**⚠️ 開發者注意事項**：
- 不要再修改此目錄中的 JSON 文件
- 所有配置更改請在根目錄的 .env 文件中進行
- 如遇問題，請參考遷移指南或聯繫開發團隊
