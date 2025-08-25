# Task Apply Resume 功能需求可行性分析

## 📋 **需求概述**

將任務應徵流程改為結構化的履歷格式，包含：
1. 結構化資料格式（JSON）
2. 特殊的聊天室訊息類型（kind='resume'）
3. Resume Dialog UI 組件
4. 圖片訊息支援（kind='image'）

## ✅ **可行性評估**

### **1. 資料庫支援** 🟢 **完全可行**

**現有表結構：**
```sql
chat_messages:
- id (bigint)
- room_id (bigint) 
- kind (enum('text','image','file','system','resume'))  -- ✅ 已支援 resume 類型
- content (text)                                        -- ✅ 可儲存 JSON 字串
- media_url (varchar(500))                              -- ✅ 圖片 URL 支援
- mime_type (varchar(100))                              -- ✅ 檔案類型支援
- created_at (timestamp)
- from_user_id (bigint unsigned)
```

**優勢：**
- ✅ `kind='resume'` 已在 ENUM 中定義
- ✅ `kind='image'` 已在 ENUM 中定義  
- ✅ `content` 欄位可儲存 JSON 字串
- ✅ `media_url` 支援圖片連結

### **2. 前端架構支援** 🟢 **完全可行**

**現有架構優勢：**
```dart
// ChatDetailPage 已有訊息類型判斷邏輯
Widget _buildMessageItem(Map<String, dynamic> message) {
  // 檢查是否為 View Resume 訊息
  if ((message['message'] ?? '').contains('申請已提交')) {
    return _buildViewResumeBubble(message);
  }
  // 可擴展為：
  if (message['kind'] == 'resume') {
    return _buildResumeBubble(message);
  }
  if (message['kind'] == 'image') {
    return _buildImageBubble(message);
  }
}
```

### **3. 資料流程設計** 🟢 **架構清晰**

## 🏗️ **實施方案**

### **階段一：資料結構設計**

#### **1.1 Resume 資料格式**
```dart
class ResumeData {
  final String applyIntroduction;
  final List<ApplyResponse> applyResponses;
  
  Map<String, dynamic> toJson() => {
    'applyIntroduction': applyIntroduction,
    'applyResponses': applyResponses.map((r) => r.toJson()).toList(),
  };
}

class ApplyResponse {
  final String applyQuestion;
  final String applyReply;
  
  Map<String, dynamic> toJson() => {
    'applyQuestion': applyQuestion,
    'applyReply': applyReply,
  };
}
```

#### **1.2 TaskApplyPage 修改**
```dart
// 在 TaskApplyPage 的提交邏輯中
final resumeData = ResumeData(
  applyIntroduction: _selfIntroController.text.trim(),
  applyResponses: [
    if (applicationQuestion != null && _englishController.text.trim().isNotEmpty)
      ApplyResponse(
        applyQuestion: applicationQuestion,
        applyReply: _englishController.text.trim(),
      ),
  ],
);

// 轉換為 JSON 字串
final resumeJsonString = jsonEncode(resumeData.toJson());
```

### **階段二：後端 API 修改**

#### **2.1 send_message.php 支援 kind 參數**
```php
// 修改 send_message.php 接受 kind 參數
$kind = isset($input['kind']) ? (string)$input['kind'] : 'text';

// 驗證 kind 值
$validKinds = ['text', 'image', 'file', 'system', 'resume'];
if (!in_array($kind, $validKinds)) {
    $kind = 'text';
}

// 插入時包含 kind
$db->query(
  "INSERT INTO chat_messages (room_id, from_user_id, content, kind) VALUES (?, ?, ?, ?)",
  [$room_id, $user_id, $message, $kind]
);
```

#### **2.2 ChatService 修改**
```dart
// 在 ChatService.sendMessage 中添加 kind 參數
Future<Map<String, dynamic>> sendMessage({
  required String roomId,
  required String message,
  String? taskId,
  String kind = 'text',  // 新增參數
}) async {
  // ...
  body: json.encode({
    'room_id': roomId,
    'message': message,
    'kind': kind,  // 傳送 kind
    if (taskId != null) 'task_id': taskId,
  }),
}
```

### **階段三：前端 UI 組件**

#### **3.1 Resume Bubble 組件**
```dart
Widget _buildResumeBubble(Map<String, dynamic> message) {
  final resumeJson = message['content'] ?? '{}';
  final resumeData = ResumeData.fromJson(jsonDecode(resumeJson));
  
  return Container(
    // Resume 氣泡樣式
    child: Column(
      children: [
        // 顯示 applyIntroduction 的前幾行
        Text(resumeData.applyIntroduction),
        const SizedBox(height: 8),
        // View Resume 按鈕
        ElevatedButton.icon(
          icon: Icon(Icons.visibility),
          label: Text('View Resume'),
          onPressed: () => _showResumeDialog(resumeData),
        ),
      ],
    ),
  );
}
```

#### **3.2 Resume Dialog**
```dart
void _showResumeDialog(ResumeData resumeData) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Container(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          children: [
            // 上半部：應徵者資訊
            _buildApplicantInfo(),
            Divider(),
            // 下半部：問題回覆列表
            Expanded(
              child: ListView(
                children: [
                  // Self-introduction
                  if (resumeData.applyIntroduction.isNotEmpty)
                    _buildResumeItem('Self Introduction', resumeData.applyIntroduction),
                  // Questions & Answers
                  ...resumeData.applyResponses.map((response) =>
                    _buildResumeItem(response.applyQuestion, response.applyReply)
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

### **階段四：圖片訊息支援**

#### **4.1 圖片氣泡組件**
```dart
Widget _buildImageBubble(Map<String, dynamic> message) {
  final imageUrl = message['media_url'] ?? '';
  
  return GestureDetector(
    onTap: () => _showImagePreview(imageUrl),
    child: Container(
      constraints: BoxConstraints(maxWidth: 200, maxHeight: 200),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    ),
  );
}
```

## 🔄 **實施策略建議**

### **關於第3點的架構選擇**

**建議方案：替代 autoMessage 邏輯** ✅

**理由：**
1. **資料一致性**：避免重複儲存相同資訊
2. **擴展性**：Resume 格式更結構化，便於未來功能擴展
3. **效能**：減少不必要的資料重複

**實施步驟：**
```dart
// 在 TaskApplyPage 中
// 1. 建立 Resume 資料
final resumeData = ResumeData(...);
final resumeJsonString = jsonEncode(resumeData.toJson());

// 2. 直接發送 Resume 訊息（替代原本的 autoMessage）
final sendRes = await chatService.sendMessage(
  roomId: roomId,
  message: resumeJsonString,
  taskId: taskId,
  kind: 'resume',  // 指定為 resume 類型
);

// 3. Socket 推播
socket.sendMessage(
  roomId: roomId,
  text: resumeJsonString,
  messageId: sendRes['message_id']?.toString(),
  kind: 'resume',
);
```

## 📊 **實施優先級**

### **Phase 1: 核心功能** (高優先級)
1. ✅ 資料結構設計 (ResumeData, ApplyResponse)
2. ✅ TaskApplyPage 修改
3. ✅ 後端 API 支援 kind 參數
4. ✅ ChatService 修改

### **Phase 2: UI 組件** (中優先級)  
1. ✅ Resume Bubble 組件
2. ✅ Resume Dialog
3. ✅ 應徵者資訊顯示

### **Phase 3: 圖片功能** (低優先級)
1. ✅ 圖片氣泡組件
2. ✅ 全螢幕預覽
3. ✅ 下載功能

## 🎯 **總結**

**可行性：🟢 完全可行**

**優勢：**
- 資料庫已完全支援所需功能
- 現有架構具備良好的擴展性
- 實施步驟清晰，風險可控

**建議：**
- 採用替代 autoMessage 的方案
- 分階段實施，先完成核心功能
- 保持向後兼容性

這個需求在技術上完全可行，且能顯著提升用戶體驗！
