# FAQ 管理系統 - 完整設計文檔

## 📋 目錄

1. [資料庫設計](#資料庫設計)
2. [後端 API](#後端-api)
3. [Laravel Admin 路由配置](#laravel-admin-路由配置)
4. [Vue Admin 管理介面](#vue-admin-管理介面)
5. [Flutter App 整合](#flutter-app-整合)
6. [部署步驟](#部署步驟)

---

## 1. 資料庫設計

### 主表：`faqs`

```sql
CREATE TABLE `faqs` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `question` VARCHAR(500) NOT NULL,
    `answer` TEXT NOT NULL,
    `category` VARCHAR(100) DEFAULT 'general',
    `is_active` TINYINT(1) DEFAULT 1,
    `display_order` INT DEFAULT 0,
    `view_count` INT UNSIGNED DEFAULT 0,
    `is_featured` TINYINT(1) DEFAULT 0,
    `language` VARCHAR(10) DEFAULT 'zh-TW',
    `created_by` INT UNSIGNED,
    `updated_by` INT UNSIGNED,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### 分類表：`faq_categories`

```sql
CREATE TABLE `faq_categories` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL,
    `slug` VARCHAR(100) NOT NULL UNIQUE,
    `description` VARCHAR(500),
    `icon` VARCHAR(50),
    `display_order` INT DEFAULT 0,
    `is_active` TINYINT(1) DEFAULT 1
);
```

---

## 2. 後端 API

### 公開 API（無需認證）

#### 獲取 FAQ 列表
- **路徑**: `GET /api/faqs/list.php`
- **參數**:
  - `category` (optional): 分類篩選
  - `language` (optional): 語言 (默認: zh-TW)
  - `is_featured` (optional): 是否熱門
  - `page` (optional): 頁碼
  - `per_page` (optional): 每頁數量

- **回應**:
```json
{
  "success": true,
  "data": {
    "faqs": [...],
    "categories": [...],
    "pagination": {
      "current_page": 1,
      "per_page": 20,
      "total": 50,
      "total_pages": 3
    }
  }
}
```

#### 查看 FAQ 詳情
- **路徑**: `GET /api/faqs/view.php?id=1`
- **功能**: 獲取 FAQ 並增加查看次數

### 管理 API（需要管理員認證）

#### 1. 獲取 FAQ 列表
- **路徑**: `GET /api/admin/faqs`
- **參數**: search, category, is_active, sort_by, sort_order, page, per_page

#### 2. 創建 FAQ
- **路徑**: `POST /api/admin/faqs`
- **Body**:
```json
{
  "question": "問題標題",
  "answer": "答案內容",
  "category": "general",
  "is_active": 1,
  "is_featured": 0,
  "language": "zh-TW"
}
```

#### 3. 更新 FAQ
- **路徑**: `PUT /api/admin/faqs/{id}`

#### 4. 刪除 FAQ
- **路徑**: `DELETE /api/admin/faqs/{id}`

#### 5. 批量更新排序
- **路徑**: `POST /api/admin/faqs/update-order`
- **Body**:
```json
{
  "items": [
    { "id": 1, "display_order": 1 },
    { "id": 2, "display_order": 2 }
  ]
}
```

#### 6. 獲取分類列表
- **路徑**: `GET /api/admin/faqs/categories`

---

## 3. Laravel Admin 路由配置

在 `admin/routes/api.php` 中添加：

```php
use App\Http\Controllers\Admin\FAQController;

Route::middleware(['auth:sanctum', 'admin'])->group(function () {
    // FAQ 管理
    Route::prefix('faqs')->group(function () {
        Route::get('/', [FAQController::class, 'index']);
        Route::post('/', [FAQController::class, 'store']);
        Route::get('/categories', [FAQController::class, 'categories']);
        Route::get('/{id}', [FAQController::class, 'show']);
        Route::put('/{id}', [FAQController::class, 'update']);
        Route::delete('/{id}', [FAQController::class, 'destroy']);
        Route::post('/update-order', [FAQController::class, 'updateOrder']);
    });
});
```

---

## 4. Vue Admin 管理介面

### 4.1 安裝拖曳套件

```bash
cd admin/frontend
npm install vuedraggable@next
```

### 4.2 創建 FAQView.vue

**位置**: `admin/frontend/src/views/FAQView.vue`

**主要功能**:
1. **列表顯示**: 表格展示所有 FAQ
2. **篩選**: 分類、狀態、搜尋
3. **新增/編輯**: Modal 表單
4. **拖曳排序**: 啟用編輯模式後可拖曳調整順序
5. **啟用/停用**: 快速切換狀態
6. **刪除**: 確認後刪除

**UI 元素**:

#### 頁面頂部
```vue
<div class="flex justify-between">
  <h2>FAQ Management</h2>
  <div class="space-x-2">
    <button @click="toggleEditMode">
      {{ editMode ? '💾 Save Order' : '✏️ Edit Order' }}
    </button>
    <button @click="showCreateModal">➕ New FAQ</button>
  </div>
</div>
```

#### 篩選區域
```vue
<div class="filters">
  <input v-model="filters.search" placeholder="Search...">
  <select v-model="filters.category">
    <option value="">All Categories</option>
    <option v-for="cat in categories" :value="cat.slug">
      {{ cat.name }}
    </option>
  </select>
  <select v-model="filters.is_active">
    <option value="">All Status</option>
    <option value="1">Active</option>
    <option value="0">Inactive</option>
  </select>
</div>
```

#### 列表表格（可拖曳）
```vue
<draggable 
  v-model="faqs" 
  :disabled="!editMode"
  tag="tbody"
  @end="handleDragEnd">
  <tr v-for="faq in faqs" :key="faq.id" class="draggable-row">
    <td v-if="editMode">☰</td> <!-- 拖曳手柄 -->
    <td>{{ faq.display_order }}</td>
    <td>{{ faq.question }}</td>
    <td>{{ faq.category_name }}</td>
    <td>
      <span :class="faq.is_active ? 'badge-success' : 'badge-gray'">
        {{ faq.is_active ? 'Active' : 'Inactive' }}
      </span>
    </td>
    <td>{{ faq.view_count }}</td>
    <td>
      <button @click="editFAQ(faq)">✏️</button>
      <button @click="toggleStatus(faq)">
        {{ faq.is_active ? '🔴 Disable' : '🟢 Enable' }}
      </button>
      <button @click="deleteFAQ(faq.id)">🗑️</button>
    </td>
  </tr>
</draggable>
```

### 4.3 Modal 表單組件

**位置**: `admin/frontend/src/components/FAQEditModal.vue`

```vue
<template>
  <div class="modal-overlay">
    <div class="modal-content">
      <h3>{{ isEdit ? 'Edit FAQ' : 'Create FAQ' }}</h3>
      
      <form @submit.prevent="handleSubmit">
        <div class="form-group">
          <label>Question *</label>
          <input v-model="form.question" required maxlength="500">
        </div>
        
        <div class="form-group">
          <label>Answer *</label>
          <textarea v-model="form.answer" required rows="6"></textarea>
        </div>
        
        <div class="form-row">
          <div class="form-group">
            <label>Category *</label>
            <select v-model="form.category" required>
              <option v-for="cat in categories" :value="cat.slug">
                {{ cat.name }}
              </option>
            </select>
          </div>
          
          <div class="form-group">
            <label>Language</label>
            <select v-model="form.language">
              <option value="zh-TW">繁體中文</option>
              <option value="en">English</option>
              <option value="zh-CN">简体中文</option>
            </select>
          </div>
        </div>
        
        <div class="form-group">
          <label class="checkbox">
            <input type="checkbox" v-model="form.is_active">
            Active
          </label>
        </div>
        
        <div class="form-group">
          <label class="checkbox">
            <input type="checkbox" v-model="form.is_featured">
            Featured (Show in Hot Questions)
          </label>
        </div>
        
        <div class="modal-actions">
          <button type="button" @click="$emit('close')">Cancel</button>
          <button type="submit" class="primary">Save</button>
        </div>
      </form>
    </div>
  </div>
</template>
```

### 4.4 拖曳排序功能實作

```typescript
// FAQView.vue <script setup>
import { ref } from 'vue'
import draggable from 'vuedraggable'

const editMode = ref(false)
const originalOrder = ref([])

// 切換編輯模式
const toggleEditMode = async () => {
  if (editMode.value) {
    // 保存排序
    await saveOrder()
  } else {
    // 進入編輯模式，保存原始順序
    originalOrder.value = [...faqs.value]
  }
  editMode.value = !editMode.value
}

// 拖曳結束
const handleDragEnd = () => {
  // 更新 display_order
  faqs.value.forEach((faq, index) => {
    faq.display_order = index + 1
  })
}

// 保存排序
const saveOrder = async () => {
  try {
    const items = faqs.value.map(faq => ({
      id: faq.id,
      display_order: faq.display_order
    }))
    
    await faqApi.updateOrder({ items })
    showSuccess('Order saved successfully')
  } catch (error) {
    // 恢復原始順序
    faqs.value = [...originalOrder.value]
    showError('Failed to save order')
  }
}
```

---

## 5. Flutter App 整合

### 5.1 更新 FAQ Page

**位置**: `lib/account/pages/faq_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  List<dynamic> faqs = [];
  List<dynamic> categories = [];
  String selectedCategory = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadFAQs();
  }

  Future<void> loadFAQs() async {
    setState(() => isLoading = true);
    
    try {
      final url = '${AppConfig.apiBaseUrl}/api/faqs/list.php'
          '?language=zh-TW${selectedCategory.isNotEmpty ? '&category=$selectedCategory' : ''}';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          faqs = data['data']['faqs'] ?? [];
          categories = data['data']['categories'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Failed to load FAQs: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 分類篩選
        if (categories.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: selectedCategory.isEmpty,
                  onSelected: (selected) {
                    setState(() => selectedCategory = '');
                    loadFAQs();
                  },
                ),
                ...categories.map((cat) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilterChip(
                    label: Text(cat['name']),
                    selected: selectedCategory == cat['slug'],
                    onSelected: (selected) {
                      setState(() => selectedCategory = cat['slug']);
                      loadFAQs();
                    },
                  ),
                )),
              ],
            ),
          ),
        
        // FAQ 列表
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: faqs.length,
                  itemBuilder: (context, index) {
                    final faq = faqs[index];
                    return FAQItem(faq: faq);
                  },
                ),
        ),
      ],
    );
  }
}

class FAQItem extends StatelessWidget {
  final Map<String, dynamic> faq;

  const FAQItem({super.key, required this.faq});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ExpansionTile(
          title: Row(
            children: [
              if (faq['is_featured'] == 1)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.star, size: 16, color: Colors.amber),
                ),
              Expanded(
                child: Text(
                  faq['question'],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(16),
                child: Text(faq['answer']),
              ),
            ),
          ],
        ),
        const Divider(height: 1),
      ],
    );
  }
}
```

---

## 6. 部署步驟

### 步驟 1: 創建資料表

```bash
mysql -u root -p your_database < database_fixes/create_faqs_table.sql
```

### 步驟 2: 添加 Laravel 路由

在 `admin/routes/api.php` 中添加 FAQ 路由。

### 步驟 3: 安裝 Vue 依賴

```bash
cd admin/frontend
npm install vuedraggable@next
```

### 步驟 4: 創建 Vue 管理介面

創建以下檔案：
- `admin/frontend/src/views/FAQView.vue`
- `admin/frontend/src/components/FAQEditModal.vue`

### 步驟 5: 添加路由到 Vue Router

```typescript
// admin/frontend/src/router/index.ts
{
  path: '/faqs',
  name: 'FAQs',
  component: () => import('../views/FAQView.vue'),
  meta: { requiresAuth: true }
}
```

### 步驟 6: 添加到導航選單

```typescript
// AppLayout.vue
{
  name: 'FAQs',
  path: '/faqs',
  icon: 'QuestionMarkCircleIcon'
}
```

### 步驟 7: 測試

1. 創建測試 FAQ
2. 測試拖曳排序
3. 測試啟用/停用
4. 在 Flutter App 中測試顯示

---

## 🎨 UI/UX 設計建議

### 拖曳排序視覺反饋

```css
.draggable-row {
  cursor: move;
  transition: all 0.3s;
}

.draggable-row:hover {
  background-color: #f3f4f6;
}

.draggable-row.sortable-chosen {
  opacity: 0.5;
  background-color: #e5e7eb;
}

.draggable-row.sortable-ghost {
  opacity: 0.3;
}
```

### 編輯模式提示

```vue
<div v-if="editMode" class="edit-mode-banner">
  ⚠️ Edit Mode Active - Drag rows to reorder, then click "Save Order"
</div>
```

---

## 📊 統計數據建議

在 Dashboard 中添加 FAQ 統計：

```typescript
{
  title: 'FAQ Statistics',
  stats: [
    { label: 'Total FAQs', value: 50 },
    { label: 'Active FAQs', value: 45 },
    { label: 'Total Views', value: 1234 },
    { label: 'Featured', value: 5 }
  ]
}
```

---

## 🔐 權限控制

建議為 FAQ 管理設置特定權限：

```php
// 在 AdminRole Model 中添加
'faqs.list', 'faqs.view', 'faqs.create', 'faqs.edit', 'faqs.delete', 'faqs.reorder'
```

---

## 📱 響應式設計

確保在手機端也能良好顯示：

```vue
<div class="faq-table-container">
  <!-- Desktop -->
  <table class="hidden md:table">...</table>
  
  <!-- Mobile -->
  <div class="md:hidden">
    <div v-for="faq in faqs" class="faq-card">
      ...
    </div>
  </div>
</div>
```

---

## 🚀 進階功能建議

1. **多語言支援**: 為每個 FAQ 添加多語言版本
2. **富文本編輯器**: 使用 TinyMCE 或 Quill 支援格式化內容
3. **標籤系統**: 為 FAQ 添加標籤以更好地分類
4. **搜尋功能**: 在 Flutter App 中添加 FAQ 搜尋
5. **使用統計**: 追蹤哪些 FAQ 最常被查看
6. **評分系統**: 讓用戶對 FAQ 有用性評分

---

完成！🎉

