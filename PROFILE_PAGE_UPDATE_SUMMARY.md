# Profile 頁面更新總結

## 完成的功能

### 1. 資料庫結構更新
- ✅ 創建了 `universities` 資料表
- ✅ 添加了大學資料（包含中文名稱、英文名稱、縮寫代號）
- ✅ 在 `users` 表中添加了 `school` 欄位

### 2. API 端點
- ✅ `backend/api/universities/list.php` - 獲取大學列表
- ✅ `backend/api/auth/update-profile.php` - 更新用戶資料

### 3. Flutter 服務類
- ✅ `lib/task/services/university_service.dart` - 大學服務類
- ✅ 提供從資料庫獲取大學列表的功能

### 4. Profile 頁面功能
- ✅ 移除 "Edit My Resume" 連結
- ✅ Email 欄位設為唯讀（不可編輯）
- ✅ Gender 欄位改為下拉選單（與註冊頁面一致）
- ✅ School 欄位改為下拉選單（使用資料庫中的大學列表）
- ✅ 添加 Save 按鈕
- ✅ 實現變更檢測功能
- ✅ 離開頁面時檢查是否有未儲存的變更
- ✅ 成功儲存後更新本地用戶資料

### 5. 資料模型更新
- ✅ 更新 `UserModel` 添加新欄位：
  - `date_of_birth`
  - `gender`
  - `country`
  - `address`
  - `about_me`
  - `school`
- ✅ 添加 `copyWith` 方法

### 6. 檔案清理
- ✅ 刪除 `lib/task/models/university_list.dart`
- ✅ 更新 `lib/task/pages/task_create_page.dart` 使用 `UniversityService`

## 性別選項
與註冊頁面保持一致：
- Male
- Female
- Non-binary
- Genderfluid
- Agender
- Bigender
- Genderqueer
- Two-spirit
- Prefer not to say
- Other

## 大學列表
從資料庫動態載入，包含：
- 國立台灣大學 (NTU)
- 國立政治大學 (NCCU)
- 國立清華大學 (NTHU)
- 國立成功大學 (NCKU)
- 等 40+ 所大學

## 使用方式

### 執行資料庫設定
```bash
php execute_universities_setup.php
```

### 在 Flutter 中使用大學服務
```dart
// 獲取大學列表
final universities = await UniversityService.getUniversities();

// 根據縮寫獲取大學名稱
final name = await UniversityService.getUniversityNameByAbbr('NCCU');
```

## 注意事項
1. 確保資料庫連線正常
2. 如果無法載入大學列表，會使用預設的 4 所大學
3. Profile 頁面會自動檢測變更並啟用/禁用 Save 按鈕
4. 離開頁面時如有未儲存變更會顯示確認對話框 