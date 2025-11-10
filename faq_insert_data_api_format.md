# FAQ 資料插入格式

## 從截圖轉換的 FAQ 資料

### 方式 1: SQL INSERT 語句

```sql
INSERT INTO faqs (
    question,
    answer,
    category,
    language,
    is_active,
    sort_order,
    created_by
) VALUES
(
    'How do I reset my password?',
    'Go to Security Settings and select "Change Password".',
    'general',
    'en',
    1,
    1,
    NULL  -- 請替換為實際的管理員 ID
),
(
    'How do I contact support?',
    'Use the "Contact Us" option in Customer Support.',
    'general',
    'en',
    1,
    2,
    NULL  -- 請替換為實際的管理員 ID
),
(
    'How do I check my points?',
    'Go to My Wallet to view your points balance.',
    'general',
    'en',
    1,
    3,
    NULL  -- 請替換為實際的管理員 ID
);
```

### 方式 2: JSON 格式（適用於 API）

```json
[
  {
    "question": "How do I reset my password?",
    "answer": "Go to Security Settings and select \"Change Password\".",
    "category": "general",
    "language": "en",
    "is_active": 1,
    "sort_order": 1
  },
  {
    "question": "How do I contact support?",
    "answer": "Use the \"Contact Us\" option in Customer Support.",
    "category": "general",
    "language": "en",
    "is_active": 1,
    "sort_order": 2
  },
  {
    "question": "How do I check my points?",
    "answer": "Go to My Wallet to view your points balance.",
    "category": "general",
    "language": "en",
    "is_active": 1,
    "sort_order": 3
  }
]
```

### 方式 3: API POST 請求格式

#### 單筆插入（POST /api/admin/faqs）

```json
{
  "question": "How do I reset my password?",
  "answer": "Go to Security Settings and select \"Change Password\".",
  "category": "general",
  "language": "en",
  "is_active": 1
}
```

### 欄位說明

- **question**: 問題標題（必填，最大 500 字元）
- **answer**: 答案內容（必填，TEXT 類型）
- **category**: 分類 slug（預設 'general'）
- **language**: 語言代碼（預設 'en'，可選 'zh-TW'）
- **is_active**: 是否啟用（1 = 啟用, 0 = 停用，預設 1）
- **sort_order**: 顯示順序（數字，預設 0，API 會自動計算）
- **created_by**: 建立者 ID（管理員 ID，API 會自動設定）

### 使用方式

1. **直接執行 SQL**: 使用 `faq_insert_data.sql` 檔案
2. **透過 Admin API**: 使用 JSON 格式，透過 POST 請求逐筆插入
3. **批量導入**: 可以修改 SQL 檔案後批量執行

