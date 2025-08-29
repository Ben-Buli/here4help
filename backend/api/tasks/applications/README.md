# 任務應徵 API 使用說明

## 概述

`apply_with_chat.php` 是一個統一的應徵 API，支持兩種模式：
1. **基本應徵模式**：只提交應徵申請
2. **完整聊天室模式**：提交應徵申請 + 創建聊天室 + 發送應徵訊息

## API 端點

```
POST /backend/api/tasks/applications/apply_with_chat.php
```

## 請求參數

### 必需參數
- `task_id` (string): 任務 ID
- `user_id` (int): 應徵者用戶 ID
- `cover_letter` (string): **自我推薦信（必填）**

### 可選參數
- `answers` (object): 問答對，格式：`{"問題標題1": "答案1", "問題標題2": "答案2"}`
- `create_chat` (boolean): 是否創建聊天室，預設為 `true`

## 使用方式

### 1. 基本應徵模式（不創建聊天室）

```json
{
  "task_id": "123",
  "user_id": 456,
  "cover_letter": "我對這個任務很感興趣，我有3年相關經驗...",
  "answers": {
    "您的經驗如何？": "我有3年相關經驗...",
    "預計完成時間？": "2週內完成"
  },
  "create_chat": false
}
```

**返回格式**：
```json
{
  "success": true,
  "data": {
    "id": 789,
    "task_id": "123",
    "user_id": 456,
    "status": "applied",
    "cover_letter": "我對這個任務很感興趣，我有3年相關經驗...",
    "answers_json": "{\"您的經驗如何？\":\"我有3年相關經驗...\",\"預計完成時間？\":\"2週內完成\"}",
    "user_name": "張三"
  },
  "message": "Application submitted successfully"
}
```

### 2. 完整聊天室模式（預設）

```json
{
  "task_id": "123",
  "user_id": 456,
  "cover_letter": "我對這個任務很感興趣，我有3年相關經驗...",
  "answers": {
    "您的經驗如何？": "我有3年相關經驗...",
    "預計完成時間？": "2週內完成"
  }
  // create_chat 預設為 true
}
```

**返回格式**：
```json
{
  "success": true,
  "data": {
    "application": {
      "id": 789,
      "task_id": "123",
      "user_id": 456,
      "status": "applied",
      "cover_letter": "我對這個任務很感興趣，我有3年相關經驗...",
      "answers_json": "{\"您的經驗如何？\":\"我有3年相關經驗...\",\"預計完成時間？\":\"2週內完成\"}",
      "user_name": "張三",
      "user_avatar": "avatar.jpg",
      "room_id": 999,
      "room_type": "application",
      "task_title": "網站開發任務",
      "creator_id": 111,
      "creator_name": "李四"
    },
    "room_id": 999,
    "message": "Application submitted and chat room created successfully"
  }
}
```

## 功能特點

### ✅ 向後兼容
- 支持新的 `answers` 格式：`{"問題標題": "答案"}`
- 預設行為與原 `apply_with_chat.php` 完全一致

### ✅ 靈活控制
- 通過 `create_chat` 參數控制功能範圍
- 支持純應徵和完整聊天室兩種模式

### ✅ 數據一致性
- 使用數據庫事務確保聊天室模式的數據一致性
- 基本模式無需事務，性能更好

### ✅ 錯誤處理
- 統一的錯誤處理和響應格式
- 詳細的驗證錯誤信息

### ✅ 必填驗證
- `cover_letter` 現在是必填項目
- 提供清晰的驗證錯誤信息

## 遷移指南

### 從 apply.php 遷移
1. 將 API 端點改為 `apply_with_chat.php`
2. 添加 `"create_chat": false` 參數
3. 確保 `cover_letter` 不為空
4. 其他參數保持不變

### 從 apply_with_chat.php 遷移
1. 無需任何修改，預設行為完全一致
2. 如需禁用聊天室功能，添加 `"create_chat": false`
3. 確保 `cover_letter` 不為空

## 注意事項

1. **事務處理**：只有 `create_chat: true` 時才使用數據庫事務
2. **聊天室類型**：創建的聊天室類型固定為 `'application'`
3. **重複應徵**：使用 UPSERT 語句，支持更新現有應徵
4. **權限檢查**：禁止應徵者應徵自己的任務
5. **必填項目**：`cover_letter` 現在是必填項目
6. **問題格式**：`answers` 使用實際問題標題作為鍵，不再支持 q1、q2、q3 格式

## 錯誤碼

- `400`: 參數驗證失敗（包括 cover_letter 為空）
- `405`: 請求方法不允許
- `500`: 服務器內部錯誤

## 歷史變更

- **v2.1**: 將 `cover_letter` 設為必填項目，移除舊的 q1~q3 格式支持
- **v2.0**: 統一 `apply.php` 和 `apply_with_chat.php` 為單一文件
- **v1.0**: 原始分離的兩個 API 文件
