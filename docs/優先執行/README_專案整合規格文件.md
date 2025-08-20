// 此文件為


# 開發日誌文件
> 開發原則：每次重要專案變更（檔案、功能的CRUD都需要備注在此文件，確保團隊開發不中斷或重複執行）
[ReadME_Here4Help專案＿變更記錄追蹤表.md](docs/優先執行/README_專案整合規格文件.md)

## 資料結構
> 資料庫現有架構說明文件，如果有資料欄位不對稱可以先來這裡比對是否有有異動紀錄
[DATABASE_SCHEMA.md]


# 登入註冊模組
> 包含帳號密碼直接登入、第三方（Google, Facebook, Apple）登入以及註冊功能

- 規格文件: [登入註冊＿規格整合文件.md](docs/優先執行/登入註冊＿規格整合文件.md)
- 執行文件: [登入註冊＿部署檢查清單.md](docs/優先執行/登入註冊＿部署檢查清單.md)


# 聊天室模組
> 聊天室列表、用戶聊天室1v1、客服聊天室B2C+1v1、ActionBar聊天室內部對任務狀態進行操作功能欄位

- 規格文件： [聊天室模組_整合規格.md](docs/優先執行/聊天室模組_整合規格.md)


# UI SCHEMA
- 主要文件參考 [THEME_USAGE_GUIDE.md](docs/THEME_USAGE_GUIDE.md)


## 🎨 主題系統模組
> 專案 UI 以新文件為主，包含主題配色、主題管理、主題切換等功能

- **主要文件**：[主題系統架構說明文件.md](../THEME_SYSTEM_ARCHITECTURE.md)
- **使用指南**：[主題使用指南.md](../THEME_USAGE_GUIDE.md)
- **核心檔案**：`lib/constants/theme_schemes_optimized.dart`
- **管理服務**：`lib/services/theme_config_manager.dart`

### **主題系統架構**
- **主題數量**：12 個核心主題（精簡自原有的 30+ 個）
- **分類系統**：business、morandi、ocean、taiwan、emotions、glassmorphism
- **特殊效果**：背景模糊、漸層背景、毛玻璃效果
- **整合方式**：支援直接使用或轉換為 Material Theme

### **使用方法**
```dart
// 直接使用主題顏色
final theme = ThemeScheme.morandiBlue;
Container(
  color: theme.primary,
  child: Text('文字', style: TextStyle(color: theme.onPrimary)),
)

// 與 Material Theme 整合
MaterialApp(
  theme: theme.toThemeData(),
  home: MyHomePage(),
)
```

### **檔案用途說明**
- **`theme_schemes_optimized.dart`**：主要主題系統，定義所有主題顏色和樣式
- **`theme_config_manager.dart`**：主題配置管理器，處理主題切換和持久化
- **`theme_aware_components.dart`**：主題感知組件，提供主題相關的 UI 組件

---

## 📱 其他 UI 模組

### **登入註冊模組**
> 包含帳號密碼直接登入、第三方（Google, Facebook, Apple）登入以及註冊功能

- 規格文件: [登入註冊＿規格整合文件.md](登入註冊＿部署檢查清單.md)

### **聊天室模組**
> 聊天室列表、用戶聊天室1v1、客服聊天室B2C+1v1、ActionBar聊天室內部對任務狀態進行操作功能欄位

- 規格文件： [聊天室模組_整合規格.md](聊天室模組_整合規格.md)

---

## 📚 舊文件（僅供參考）
- @cursor_todo ... etc