# TaskHistoryPage 404 錯誤修正

## 問題分析

`TaskHistoryPage` 出現 404 錯誤的根本原因是 **URL 構建錯誤**，導致重複的路徑片段。

### 錯誤的 URL 構建

**問題 URL**：
```
http://127.0.0.1:8888/here4help/backend/backend/api/ratings/posted.php
```

**問題分析**：
- `AppConfig.apiBaseUrl` = `http://127.0.0.1:8888/here4help`
- 錯誤的構建方式：`$_baseUrl/backend/api/ratings/posted.php`
- 結果：重複的 `/backend/backend/` 路徑

## 修正內容

### 1. RatingsService 修正

**檔案**: `lib/task/services/ratings_service.dart`

**修正前**：
```dart
class RatingsService {
  static final String _baseUrl = AppConfig.apiBaseUrl;

  static Future<Paged<TaskCard>> fetchPosted(int page) async {
    final response = await HttpClientService.get(
      '$_baseUrl/backend/api/ratings/posted.php?page=$page&per_page=20',
      useQueryParamToken: true,
    );
  }
}
```

**修正後**：
```dart
class RatingsService {
  static Future<Paged<TaskCard>> fetchPosted(int page) async {
    final response = await HttpClientService.get(
      '${AppConfig.api('/ratings/posted.php')}?page=$page&per_page=20',
      useQueryParamToken: true,
    );
  }
}
```

### 2. 其他相關 API 修正

同樣修正了以下方法：
- `fetchAccepted()` - 修正 `/ratings/accepted.php`
- `fetchNotSelected()` - 修正 `/ratings/not-selected.php`  
- `createRating()` - 修正 `/tasks/ratings.php`

### 3. 之前已修正的檔案

- `lib/services/api/review_api.dart`
- `lib/task/services/application_question_service.dart`

## 修正結果

### 修正前
```
❌ http://127.0.0.1:8888/here4help/backend/backend/api/ratings/posted.php
```

### 修正後  
```
✅ http://127.0.0.1:8888/here4help/backend/api/ratings/posted.php
```

## 驗證

1. **後端 API 存在**：`backend/api/ratings/posted.php` ✅
2. **URL 構建正確**：使用 `AppConfig.api()` 方法 ✅
3. **語法檢查通過**：無 linter 錯誤 ✅

## 根本解決方案

**統一使用 `AppConfig.api()` 方法**：
```dart
// ✅ 正確方式
AppConfig.api('/ratings/posted.php')

// ❌ 錯誤方式  
'${AppConfig.apiBaseUrl}/backend/api/ratings/posted.php'
```

這確保了 URL 構建的一致性，避免路徑重複問題。
